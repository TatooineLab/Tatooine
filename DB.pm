package Tatooine::DB;

=nd
Package: Tatooine::DB
	Class to work with the database.
=cut

use strict;
use warnings;

use utf8;

use base qw / Tatooine::Base /;

use Tatooine::Error;
use DBI;

=nd
Method: new
	The class constructor.
=cut
sub new {
	my ($class, $attr_child) = @_;
	# Проверяем атрибуты потоска
	$attr_child = {} 	unless $attr_child;
	$attr_child->{db} = {} 	unless $attr_child->{db};
	# Заполняем поля объекта
	my %attr = %{$attr_child};
	$attr{db} = {
		database => Tatooine::Base::C->{db}{name},	# Имя базы данных
		host	=> Tatooine::Base::C->{db}{host},	# Хост
		port	=> Tatooine::Base::C->{db}{port},	# Порт
		login	=> Tatooine::Base::C->{db}{login},	# Имя пользователя БД
		pass	=> Tatooine::Base::C->{db}{pass},	# Пароль БД
		%{$attr_child->{db}}
	};

	$class->SUPER::new(\%attr);
}

=nd
Method: connectDB
	Connect to the database.
=cut
sub connectDB {
	my $self = shift;
	if (!$self->R->dbh or !$self->R->dbh->ping) {
		my $data_source = "dbi:Pg:database=$self->{db}{database};host=$self->{db}{host};port=$self->{db}{port}";
		$self->R->{dbh} = DBI->connect($data_source, $self->{db}{login}, $self->{db}{pass}) or systemError('Can not connect to database');
	}
}

=nd
Method: insert(ref %fields)
	Добавить запись.

Parameters:
	ref %fields    	- поля записи, в которые будут добавленны данные
	$table 		- название таблицы, в которую добавляют данные (по умолчанию берётся из модуля)

See Also:
	update
=cut
sub insert {
	my ($self, $fields, $table, $return) = @_;
	#Чистим поток от прав пользователя
	delete $fields->{roles};
	#Подготавливаем SQL-запрос
	my ($fields_query, $placeholders);
	#Поля и плэйсхолдеры
	$fields_query .= " ".$_."," foreach keys %{$fields};
	$placeholders .= " "."?," foreach keys %{$fields};
	$table = $self->table unless $table;
	#Удаляем лишние запятые
	chop($fields_query); chop($placeholders);
	# Возвращаемое значение
	if ($return){
		$return = 'RETURNING '.$return;
	} else {
		$return = "";
	}
	my $query = qq{INSERT INTO $table($fields_query) values($placeholders) $return};
	#Биндим значения
	my @bind_values;
	push @bind_values, $_ foreach values %{$fields};
	# Подготавливаем запрос
	my $sth = $self->{router}{dbh}->prepare($query);
	# Выполняем его
	$sth->execute(@bind_values) or systemError("can not execute $query");
	# Получаем id добавленной записи
	my $id = $sth->fetch()->[0] if $return;
	return $id if $id;
}

=nd
Method: update($router_object, ref %$fields, $where)
	Обновить запись.

Parameters:
	ref %fields   	- имя полей которые следует обновить
	$where        	- какую именно запись нужно обновить (поле sql-запроса WHERE)
	$table 		- название таблицы, в которую добавляют данные (по умолчанию берётся из модуля)
=cut
sub update {
	my($self, $fields, $where, $table) = @_;
	#Чистим поток от прав пользователя
	delete $fields->{roles};
	##Подготовка sql запроса
	#Биндим значения
	my @bind_values;
	push @bind_values, $_ foreach values %{$fields};
	my ($where_fields, @tmp);
	push @tmp, "$_='$where->{$_}'" foreach keys %{$where};
	$where_fields = join(' AND ', @tmp);
	#Поля для запроса(добавляем плэйхолдеры)
	my ($fields_str, @work_fields);
	$fields_str .= " ".$_."=?," foreach keys %{$fields};
	# Удаляем лишине запятые
	chop($fields_str);
	# Вытаскиваем таблицу
	$table = $self->table if (!$table);
	my $query = qq{UPDATE $table SET $fields_str WHERE $where_fields};

	#Обновляем запись
	$self->{router}{dbh}->do($query, undef, @bind_values) or systemError("can't execute $query");
}

=nd
Method: delete($router_object)
	Удалить запись.
Parameters:
	$value       	- значение id. По умолчанию берётся из $self->{router}{flow}{id}
	$table 		- название таблицы, в которую добавляют данные (по умолчанию берётся из модуля)
=cut
sub delete {
	my ($self, $where, $table) = @_;
	my (@bind_values, $where_fields, @tmp);

	#SQL запрос
	# Получаем таблицы
	$table = $self->table unless $table;

	# Условия удаления
	foreach (keys %{$where}) {
		# Если переменная имеет знак, отличный от '='
		if ( ref $where->{$_} eq 'HASH' and $where->{$_}{sign} ){
			my $sign = $where->{$_}{sign};
			my $val = $where->{$_}{value};
			my $key = $_;
			push @tmp, $key." ".$sign." ?" ;
			push @bind_values, $val;
		} else {
			push @tmp, "$_=?" ;
			push @bind_values, $where->{$_};
		}
	}
	$where_fields = join(' AND ', @tmp);
	unless($where_fields){
		$where_fields = 'WHERE id=?';
		push @bind_values, $self->{router}->F->{id};
	} else {
		$where_fields = 'WHERE '.$where_fields;
	}

	# Запрос
	my $query = qq{DELETE FROM $table $where_fields};
	#Удаляем запись
	$self->{router}{dbh}->do($query, undef, @bind_values) or systemError("can't execute $query");
}

=nd
Method: getRecord
	Метод получает хэш и из него конструирует sql-запрос выборки строк
=cut
sub getRecord {
	my ($self, $sql) = @_;

	$sql->{fields} = '*' unless $sql->{fields};
	$sql->{table} = $self->table unless $sql->{table};

	## Подготавливаем запрос
	# Разбираем WHERE
	my (@bind_values, $where_fields, $order, @tmp);
	foreach (keys %{$sql->{where}}) {
		next unless $sql->{where}{$_};
		# Полнотекстовый поиск
		if ( ref $sql->{where}{$_} eq 'HASH' and $sql->{where}{$_}{tsearch} and $sql->{where}{$_}{sign} ){
			my $val = join(' '.$sql->{where}{$_}{sign}.' ', split(' ', $sql->{where}{$_}{value}));
			my $key = $_;
			# Если присутствует поле key в хеше, то заменяем текущий ключ
			$key = $sql->{where}{$_}{key} if $sql->{where}{$_}{key};
			# Объединение
			if (@tmp > 0) {
				if ($sql->{where}{$_}{union}) {
					push @tmp, $sql->{where}{$_}{union};
				} else {
					push @tmp, 'AND';
				}
			}
			push @tmp, "to_tsvector('english', ".$key.") @@ to_tsquery(?)" ;
			push @bind_values, $val;
		# Если переменная имеет параметр value
		} elsif ( ref $sql->{where}{$_} eq 'HASH' and ($sql->{where}{$_}{value} or $sql->{where}{$_}{value} == 0 or $sql->{where}{$_}{sign})){
			my $sign = $sql->{where}{$_}{sign};
			$sign = '=' unless $sign;
			my $val = $sql->{where}{$_}{value};
			my $key = $_;
			# Если присутствует поле key в хеше, то заменяем текущий ключ
			$key = $sql->{where}{$_}{key} if $sql->{where}{$_}{key};

			if (@tmp > 0) {
				push @tmp, 'AND';
			}

			# Операторы IN и NOT IN
			if ($sign eq 'NOT IN' or $sign eq 'IN'){
				# Формируем текст параметра запроса (ex. NOT IN (?, ?, ?))
				my $str = $key." ".$sign." (";
				# Количество ? соответствует количеству значений $val
				foreach my $i (@{$val}) {
					$str .= ($i ne $$val[-1]) ? '?,' : '?';
				}
				$str .= ')';

				push @tmp, $str;
				push @bind_values, @{$val};
			# Объединение
			} elsif ( ref $val eq 'ARRAY' ) {
				push @tmp, '(';
				my $n = 0;
				foreach my $i (@{$val}) {
					if ($n > 0) {
						push @tmp, $sql->{where}{$_}{union};
					}

					my $k = $i->{key};
					my $v = $i->{val};
					my $s = $i->{sign} ? $i->{sign} : '=';
					if ($v eq 'IS NULL' or $v eq 'IS NOT NULL') {
						push @tmp, $k." ".$v;
					} else {
						push @tmp, $k." ".$s." ?";
						push @bind_values, $v;
					}

					$n++;
				}
				push @tmp, ')';
			} else {
				if ($val eq 'IS NULL' or $val eq 'IS NOT NULL') {
					push @tmp, $key." ".$val;
				} else {
					push @tmp, $key." ".$sign." ?" ;
					push @bind_values, $val;
				}
			}
		} elsif ($sql->{where}{$_} and $sql->{where}{$_} eq 'IS NULL' or $sql->{where}{$_} eq 'IS NOT NULL') {
			push @tmp, 'AND' if @tmp > 0;
			push @tmp, "$_ ".$sql->{where}{$_};
		} else {
			push @tmp, 'AND' if @tmp > 0;
			push @tmp, "$_=?" ;
			push @bind_values, $sql->{where}{$_};
		}
	}
	$where_fields = join(' ', @tmp);
	$where_fields = ' WHERE '.$where_fields	if($where_fields);
	# sql-запрос
	my $query = qq{ SELECT $sql->{fields} FROM $sql->{table} $where_fields};

	# Добавляем ORDER
	$query .= ' ORDER BY '.$sql->{order}	if ($sql->{order});
	# Добавляем LIMIT
	$query .= ' LIMIT '.$sql->{limit}	if ($sql->{limit});

	my $sth = $self->{router}{dbh}->prepare($query);
	# Выполняем запрос
	$sth->execute(@bind_values) or systemError("can't execute $query");

	#Получаем значения и помещаем их в поток
	my @data;
	if ($sql->{flow_type} and ($sql->{flow_type} eq 'array' or $sql->{flow_type} eq 'arrayref')){
		push @data, $_ while $_ = $sth->fetchrow_array;
	} else {
		push @data, $_ while $_ = $sth->fetchrow_hashref;
	}

	if ($sql->{hash_name}) {
		# Пишем в поток(или массив или переменную)
		if(@data > 1 or ($sql->{flow_type} and ($sql->{flow_type} eq 'arrayref' or $sql->{flow_type} eq 'hashref_array'))) {
			$self->{router}{flow}{$sql->{hash_name}} = \@data;
		} else {
			$self->{router}{flow}{$sql->{hash_name}} = $data[0];
		}
	} else {
		# Пишем в поток(или массив или переменную)
		if(@data > 1 or ($sql->{flow_type} and ($sql->{flow_type} eq 'arrayref' or $sql->{flow_type} eq 'hashref_array'))) {
			return \@data;
		} else {
			return $data[0];
		}
	}
}

=nd
Function: getList
	Процедура получения списка записей

Parameters:
	$options - хеш с различными параметрами в запросе к базе данных
	$options->{where}	- условия выборки
	$options->{fields}	- поля выборки
	$options->{order}	- порядок выборки
	$options->{flow_type}	- тип возвращаемого объекта (массив, хеш)
=cut
sub getList {
	my ($self, $options) = @_;

	$options = {} unless $options;
	$options->{where} = {} unless $options->{where};

	# Получаем список записей
	$self->{list} = $self->getRecord(
		{
			fields => $options->{fields} || '*',
			order => $options->{order} || 'sort' || 'id',
			where => $options->{where},
			flow_type => $options->{flow_type} || 'hashref_array'
		}
	);
}

=nd
Method: list
	Метод доступа к списку записей
=cut
sub list {
	my ($self, $options) = @_;
	# Получаем информацию о списке самолётов, если её нет
	$self->getList($options) if !$self->{list}->[0];
	$self->{list}
}

1;