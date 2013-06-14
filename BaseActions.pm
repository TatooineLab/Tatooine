package Tatooine::BaseActions;

=nd
Package: BaseActions
	Абстрактный класс для регистрации базовых действии программы действий.

=cut

use strict;
use warnings;

use utf8;

use JSON;			# модуль для работы с JSON
use Tatooine::Error;		# Модуль для работы с ошибками

=nd
Method: registerActions
	Метод регистрации действий по умолчанию

=cut
sub registerActions {
	my $self = shift;
	my $router = $self->{router};

	# Главная страница модуля
	$router->registerAction($self->Prefix.'_MAIN' => { do => sub {
			my $S = shift;

			$self->mO->setTpl('MAIN');
			return 'STOP';
		}
	});

	# Вывод списка записей
	$router->registerAction($self->Prefix.'_LOAD_CONTENT' => { do => sub {
			my $S = shift;
			# Если нет подключения к базе, то коннектимся
			if (!$S->dbh or !$S->dbh->ping) {
				$self->mO->connectDB;
			}

			# Получаем список записей
			$S->F->{list} = $self->mO->getList;
			
		    # Получаем количество записей
			$S->F->{count_record} =  $self->getRecord(
				{
					fields      => 'count(*)',
					table       => $self->{db}->{table},
					flow_type   => 'array'
				}
			);

			$self->mO->setTpl('CONTENT');
			return 'STOP';
		}
	});

	# Форма добавления/редактирования записи
	$router->registerAction($self->Prefix.'_LOAD_FORM' => { do => sub {
			my $S = shift;

			# Если нет подключения к базе, то коннектимся
			if (!$S->dbh or !$S->dbh->ping) {
				$self->mO->connectDB;
			}

			# Если запись редактируется
			if ($S->F->{id} and $S->F->{id} ne 'undefined'){
				$S->F->{data} = $self->mO->getRecord({
					where => {
						id => $S->F->{id}
					}
				});
			}

			$self->mO->setTpl('FORM');
			return 'STOP';
		}
	});

	# Добавление/редактирование записи
	$router->registerAction($self->Prefix.'_SAVE' => { do => sub {
			my $S = shift;

			# Проверяем введённые данные на корректность
			$self->mO->validateData;
			# Если присутствует ошибка, то завершаем скрипт
			return 'STOP' if $S->F->{error};

			## Вытаскиваем ошибки
			my $errors = checkErrors('USER');
			unless ($errors) {
				# Если нет подключения к базе, то коннектимся
				if (!$S->dbh or !$S->dbh->ping) {
					$self->mO->connectDB;
				}

				# Получаем список параметров новой записи
				my %fields = %{$S->F};
				# Удаляем ненужные параметры
				delete @fields{qw(id save)};

				# Присваиваем значения undef пустым строкам
				foreach my $key (keys %fields){
					$fields{$key} = undef unless $fields{$key};
				}

				# Редактирование записи
				if($S->F->{id}){
					my %where_field = ('id' => $S->F->{id});
					$self->mO->update(\%fields, \%where_field);
				# Добавление записи
				} else {
					$self->mO->insert(\%fields);
				}

				# Формируем сообщение
				$S->F->{message} = "Record is saved.";
			}

			# Преобразуем сообщение в JSON формат
			$S->F->{data} = to_json( $S->F->{message}, {allow_nonref => 1} );

			$S->setSystemTpl('JSON');
			return 'STOP';
		}
	});

	# Окно удаления записи
	$router->registerAction($self->Prefix.'_LOAD_WND_DELETE' => { do => sub {
			my $S = shift;

			$self->mO->setTpl('WND_DELETE');
			return 'STOP';
		}
	});

	# Удалить запись
	$router->registerAction($self->Prefix.'_DELETE' => { do => sub {
			my $S = shift;

			# Если нет подключения к базе, то коннектимся
			if (!$S->dbh or !$S->dbh->ping) {
				$self->mO->connectDB;
			}

			# Удаляем запись
			$self->mO->delete({ id => $S->F->{id} });

			# Формируем сообщение
			$S->F->{message}{class} = 'success';
			push @{$S->F->{message}{msg}}, "Record is deleted.";

			# Преобразуем сообщение в JSON формат
			$S->F->{data} = to_json( $S->F->{message}, {allow_nonref => 1} );
			$S->setSystemTpl('JSON');
			return 'STOP';
		}
	});

	# Валидация полей формы редактирования
	$router->registerAction($self->Prefix.'_VALIDATE' => { do => sub {
			my $S = shift;

			# Проверяем введённые данные
			$self->mO->validateData;

			# Преобразуем полученные данные в JSON формат
			$S->F->{data} = to_json( $S->F->{error}, {allow_nonref => 1} );
			$S->setSystemTpl('JSON');
			return 'STOP';
		}
	});
}

=nd
Method: selectActions
	Метод для выбора действий в зависимости от пришедших параметров

=cut
sub selectActions {
	my $self = shift;
	my $R = $self->{router};
	my @act;

	push @act, $self->Prefix.'_MAIN';
	push @act, $self->Prefix.'_SAVE'		if $R->F->{save};
	push @act, $self->Prefix.'_LOAD_CONTENT'	if $R->F->{load_content};
	push @act, $self->Prefix.'_LOAD_FORM'		if $R->F->{load_form};
	push @act, $self->Prefix.'_LOAD_WND_DELETE' 	if $R->F->{load_wnd_delete};
	push @act, $self->Prefix.'_DELETE' 		if $R->F->{delete_record};
	push @act, $self->Prefix.'_VALIDATE' 		if $R->F->{validate};

	return @act;
}

1;
