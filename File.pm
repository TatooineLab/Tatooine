package Tatooine::File;

=nd
Package: File
	Класс для работы с файлами

=cut

use strict;
use warnings;

use Tatooine::Base;			# Базовый класс для работы с базой
use Tatooine::Error;		# Модуль для работы с ошибками
use JSON;		# модуль для формирования с JSON данными

=nd
Method: registeFilerActions
	Метод регистрации действий для работы с файлами

=cut
sub registerFileActions {
	my $self = shift;
	my $script = $self->{script};

	# Вывод списка записей
	$script->registerAction($self->mN.'_FILE_LIST' => { do => sub {
			my $S = shift;
			# Если нет подключения к базе, то коннектимся
			if (!$S->dbh or !$S->dbh->ping) {
				$S->connectDB;
			}

			my $where = { id_record => $S->F->{id_record} };
			$where->{id_block} = $S->F->{id_block} if ( $S->F->{id_block} and $S->F->{id_block} ne 'all' );

			# Получаем список записей
			$S->F->{file_list} = $self->mO->getFileList({
				where => $where
			});

			# Путь к файлам
			$S->F->{path} = $self->mO->{file}{path};

			$self->mO->setTpl('FILE_LIST');
			return 'STOP';
		}
	});

	# Добавление/редактирование записи
	$script->registerAction($self->mN.'_FILE_SAVE' => { do => sub {
			my $S = shift;

			# Загружаем файл на сервер
			my $file_name = $self->mO->upload;

			# Формируем сообщение
			$S->F->{message} = "The file was successfully uploaded.";

			# Преобразуем сообщение в JSON формат
			$S->F->{data} = to_json( $S->F->{message}, {allow_nonref => 1} );
			$S->setTpl('JSON_VALUE');
			return 'STOP';
		}
	});

	# Форма добавления/редактирования записи
	$script->registerAction($self->mN.'_FILE_FORM' => { do => sub {
			my $S = shift;

			$self->mO->setTpl('FILE_FORM');
			return 'STOP';
		}
	});

	# Окно удаления записи
	$script->registerAction($self->mN.'_FILE_WND_DELETE' => { do => sub {
			my $S = shift;

			$self->mO->setTpl('FILE_WND_DELETE');
			return 'STOP';
		}
	});

	# Удалить запись
	$script->registerAction($self->mN.'_FILE_DELETE' => { do => sub {
			my $S = shift;

			# Если нет подключения к базе, то коннектимся
			if (!$S->dbh or !$S->dbh->ping) {
				$S->connectDB;
			}

			my $file = $self->mO->getRecord({
				table => 'file',
				where => {
					id => $S->F->{id},
					id_user => $S->{User}{id}
				}
			});

			# Удаляем файл из каталога
			my $fname = $file->{id_record}.'_'.$file->{id}.'.'.$file->{ext};
			my $path = $self->mO->filePath;
			`rm "$path${fname}"`;

			# Удаляем запись
			$self->mO->deleteRecord({ id => $S->F->{id}, id_user => $S->{User}{id} }, 'file');

			# Формируем сообщение
			$S->F->{message}{class} = 'success';
			push @{$S->F->{message}{msg}}, "The file was successfully deleted.";

			# Преобразуем сообщение в JSON формат
			$S->F->{data} = to_json( $S->F->{message}, {allow_nonref => 1} );
			$S->setTpl('JSON_VALUE');
			return 'STOP';
		}
	});
}

=nd
Method: selectFileActions
	Метод для выбора действий в зависимости от пришедших параметров

=cut
sub selectFileActions {
	my $self = shift;
	my $S = $self->{script};
	my @act;

	push @act, $self->mN.'_FILE_LIST'	if $S->F->{file_list};
	push @act, $self->mN.'_FILE_SAVE'	if $S->F->{file_save};
	push @act, $self->mN.'_FILE_FORM'	if $S->F->{file_form};
	push @act, $self->mN.'_FILE_WND_DELETE' if $S->F->{file_wnd_delete};
	push @act, $self->mN.'_FILE_DELETE' 	if $S->F->{file_delete};

	return @act;
}

=nd
Method: setFileTpl($name_tpl)
	Устанавливает шаблон. Принимает имя шаблона.
=cut
sub setFileTpl {
	my ($self, $tpl) = @_;

	$tpl = 'module/file/form.tpl'		if ($tpl eq 'FILE_FORM');
	$tpl = 'module/file/content.tpl'	if ($tpl eq 'FILE_LIST');
	$tpl = 'module/file/delete_wnd.tpl'	if ($tpl eq 'FILE_WND_DELETE');

	return $tpl;
}

=nd
Function: getFileList
	Процедура получения списка файлов
=cut
sub getFileList {
	my ($self, $options) = @_;

	$options = {} unless $options;
	$options->{where} = {} unless $options->{where};
	# Идентификатор пользователя системы
	$options->{where}{'U.id'} = $self->S->{User}{id};

	# Получаем список самолётов
	$self->{file_list} = $self->getRecord(
		{
			table => 'file as F
				JOIN users as U ON U.id = F.id_user',
			fields => $options->{fields} || 'F.*',
			order => $options->{order} || 'F.sort, F.id',
			where => $options->{where},
			flow_type => $options->{flow_type} || 'hashref_array'
		}
	);
}

=nd
Method: uploadFile
	Загружает файл на сервер.

Parameters:
	$opt->{file}		- исходный файл
	$opt->{id_record}	- id записи, для которой грузится файл
	$opt->{table}		- имя таблицы, для которой загружается файл
	$opt->{path}		- путь к папке,в которую будет загружен файл
=cut
sub upload {
	my $self = shift;

	my %fields = %{$self->S->F};
	my $file = $self->S->F->{'pictures[0]'} || $self->S->F->{'files[0]'};

	# Удаляем ненужные параметры
	delete @fields{qw(id path file_save)};

	# Присваиваем значения undef пустым строкам
	foreach my $key (keys %fields){
		$fields{$key} = undef unless $fields{$key};
		delete $fields{$key} if ($key =~ /files/ or $key =~ /pictures/);
	}

	$fields{tbl} = $self->table unless $fields{tbl};
	$fields{sort} = 1 unless $fields{sort};
	$fields{file_size} = -s $file;
	$fields{id_user} = $self->S->{User}{id};
	$fields{id_block} = undef if ( $fields{id_block} and $fields{id_block} eq 'all' );


	# Выделяем имя файла из параметра
	my ($name) = $file =~ m#([^\\/:]+)$#;

	# Получаем расширение файла
	my $ext = $name;
	$ext =~ s/[^.]+\.(.*)/$1/gi;

	# Имя загруженного файла
	my $fname;

	# Если расширение найдено в имени файла
	if ($ext ne $name) {
		# Если нет подключения к базе, то коннектимся
		if (!$self->S->dbh or !$self->S->dbh->ping) {
			$self->S->connectDB;
		}

		$fields{ext} = $ext;

		# Добавляем информацию о файле в базу
		my $id = $self->addRecord(
			\%fields,
			'file',
			'id'
		);

		# Имя файла
		$fname = $fields{id_record}.'_'.$id;

		# Загружаем файл на сервер
		$self->uploadFile($file, $fname, $self->S->F->{path} || $self->filePath);
	}

	return $fname.'.'.$ext;
}

=nd
Method: uploadFile
	Загружает файлы на сервер.

Parameters:
	$input_file -	исходный файл
	$file_name  -	имя файла, который будет записан в базу
=cut

sub uploadFile {
	my ($self, $input_file, $file_name, $down_path) = @_;
	# Парсим имя и даем ему имя по id
	my ($file_extension) = $input_file =~ m#([^\\/:]+)$#;
	$file_extension =~ s/[^.]+\.(.*)/$1/gi;
	unless ($file_name){
		$file_name = $input_file;
		$file_name =~ s/\.$file_extension//;
	}
	$file_name .= ".$file_extension" if $file_name;
	#Получаем путь куда грузим
	$down_path = $self->filePath() unless $down_path;
	open(OUT,">$down_path$file_name");
	binmode(OUT, ':bytes');
	# читаем входной поток и пишем в файл
	while (<$input_file>) {
		print OUT $_;
	}
	close(OUT);
	return $file_name;
}

1;