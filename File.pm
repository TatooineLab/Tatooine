package Tatooine::File;

=nd
Package: File
	Class for working with files.
=cut

use strict;
use warnings;

use utf8;

use parent qw(Tatooine::Base);

use Tatooine::Error;	# Class for handling errors.
use JSON;

=nd
Method: uploadFile($opt)
	The method of uploading files on the server.

Parameters:
	$opt			-	hash with parameters
	$opt->{file}	-	source file
	$opt->{name}	-	The new file name to write to the server
	$opt->{path}	-	Path to upload file
=cut
sub uploadFile {
	my ($self, $opt) = @_;
	my ($input_file, $file_name, $path);

	$input_file = $opt->{file};
	$file_name = $opt->{name};

	# The path for uploading
	$path = $opt->{path};
	$path = $self->filePath() unless $path;

	# Get the file extension
	my ($file_extension) = $input_file =~ m#([^.]+)$#;
	$file_extension =~ /\.([^.]+)$/gi;

	unless ($file_name){
		$file_name = $input_file;
		$file_name =~ s/\.$file_extension//;
	}
	$file_name .= ".$file_extension" if $file_name;

	open(OUT,">$path$file_name");
	binmode(OUT, ':bytes');
	while (<$input_file>) {
		print OUT $_;
	}
	close(OUT);

	return $file_name;
}

=nd
Method: registerFileActions
	The method of recording actions for the module.
=cut
sub registerFileActions {
	my $self = shift;
	my $router = $self->{router};

	# Главная страница
	$router->registerAction($self->Prefix.'_FILE_MAIN' => { do => sub {
			my $S = shift;

			$self->mO->setFileTpl('MAIN');
			return 'STOP';
		}
	});

	# Вывод списка записей
	$router->registerAction($self->Prefix.'_FILE_LIST' => { do => sub {
			my $S = shift;
			$self->mO->connectDB;

			# Получаем список записей
			$S->F->{file_list} = $self->mO->getFileList;

			$self->mO->setFileTpl('LIST');
			return 'STOP';
		}
	});

	# Добавление/редактирование записи
	$router->registerAction($self->Prefix.'_FILE_UPLOAD' => { do => sub {
			my $S = shift;

			# Загружаем файл на сервер
 			my $file_name = $self->mO->fileUpload;

			# Формируем сообщение
			$S->F->{message} = "The file was successfully uploaded.";

			# Преобразуем сообщение в JSON формат
			$S->F->{data} = to_json( $S->F->{message}, {allow_nonref => 1} );
			$S->setSystemTpl('JSON');
			return 'STOP';
		}
	});

	# Форма добавления/редактирования записи
	$router->registerAction($self->Prefix.'_FILE_FORM' => { do => sub {
			my $S = shift;
			$self->mO->connectDB;

			# Если запись редактируется
			if ($S->F->{id} and $S->F->{id} ne 'undefined'){
				$S->F->{data} = $self->mO->getRecord({
					where => {
						id => $S->F->{id}
					}
				});
			}

			$self->mO->setFileTpl('FORM');
			return 'STOP';
		}
	});

	# Добавление/редактирование записи
	$router->registerAction($self->Prefix.'_FILE_SAVE' => { do => sub {
			my $S = shift;

			# Проверяем введённые данные на корректность
			$self->mO->validateData;
			# Если присутствует ошибка, то завершаем скрипт
			return 'STOP' if $S->F->{error};

			## Вытаскиваем ошибки
			my $errors = checkErrors('USER');
			unless ($errors) {
				$self->mO->connectDB;

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
				$S->F->{message} = "File is saved.";
			}

			# Преобразуем сообщение в JSON формат
			$S->F->{data} = to_json( $S->F->{message}, {allow_nonref => 1} );
			$S->setSystemTpl('JSON');
			return 'STOP';
		}
	});

	# Окно удаления записи
	$router->registerAction($self->Prefix.'_FILE_WND_DELETE' => { do => sub {
			my $S = shift;

			$self->mO->setFileTpl('WND_DELETE');
			return 'STOP';
		}
	});

	# Удалить запись
	$router->registerAction($self->Prefix.'_FILE_DELETE' => { do => sub {
			my $S = shift;
			$self->connectDB;

			if ($self->R->F->{id}){
				# Get file info
				my $f = $self->getRecord({
					table => $self->tableFile,
					where => {
						id => $self->R->F->{id}
					}
				});

				# Delete record from database
				$self->delete({ id => $self->R->F->{id} }, $self->tableFile);

				# Delete file from path
				$self->mO->fileDelete({
					id => $f->{id},
					id_record => $f->{id_record},
					path => $self->filePath
				}) if $f;

				# Формируем сообщение
				$S->F->{message}{class} = 'success';
				push @{$S->F->{message}{msg}}, "File is deleted.";
			} else {
				# Формируем сообщение
				$S->F->{message}{class} = 'error';
				push @{$S->F->{message}{msg}}, "Error. File is not deleted.";
			}

			# Преобразуем сообщение в JSON формат
			$S->F->{data} = to_json( $S->F->{message}, {allow_nonref => 1} );
			$S->setSystemTpl('JSON');
			return 'STOP';
		}
	});
}

=nd
Method: selectActions
	Метод для выбора действий в зависимости от пришедших параметров

=cut
sub selectFileActions {
	my $self = shift;
	my $R = $self->{router};
	my @act;

	push @act, $self->Prefix.'_FILE_MAIN'			if $R->F->{file_main};
	push @act, $self->Prefix.'_FILE_UPLOAD'		if $R->F->{file_upload};
	push @act, $self->Prefix.'_FILE_LIST'			if $R->F->{file_list};
	push @act, $self->Prefix.'_FILE_WND_DELETE' 	if $R->F->{file_wnd_delete};
	push @act, $self->Prefix.'_FILE_DELETE' 		if $R->F->{file_delete};

	push @act, $self->Prefix.'_FILE_FORM'			if $R->F->{file_form};
	push @act, $self->Prefix.'_FILE_SAVE'			if $R->F->{file_save};

	return @act;
}

=nd
Method: setFileTpl($name_tpl)
	The method that sets the template.

Parameters:
	$name_tpl - template name
=cut
sub setFileTpl {
	my ($self, $name_tpl) = @_;
	# Set the template, the data are taken from the config file
	$self->R->{template} = $self->T->{system}{file}{$name_tpl};
}

=nd
Method: tableFile
	The method of access to the name of the table you are working on a module.
=cut
sub tableFile { shift->{db}{file_table} }

=nd
Method: getFileList
	The method for getting the file list from database.

Parameters:
	$opt - hash with parameters
=cut
sub getFileList {
	my ($self, $opt) = @_;
	$opt = {} unless $opt;

	# Идентификатор записи, для которой достаются картинки
	my $id = $opt->{id_record} || $self->R->F->{id};
	# Таблица, в которой находится запись
	my $table = $opt->{table} || $self->table;

	$self->connectDB;

	# Путь к файлам
	$self->R->F->{path} = $self->{file}{path};

	$self->getRecord({
			table => $self->tableFile,
			where => {
				id_record => $id,
				tbl => $table
			},
			flow_type => 'hashref_array'
	});
}

=nd
Method: fileUpload
	The method for uploading file to a server.

Parameters:
	$opt->{file}		- source file
	$opt->{id_record}	- The ID of the record for which the file is uploaded.
	$opt->{table}		- Name of the table on which an file is uploaded.
	$opt->{path}		- The path to the folder in which the file will be uploaded.
=cut
sub fileUpload {
	my ($self, $opt) = @_;
	$opt = {} unless $opt;

	$opt->{table} = $self->table unless $opt->{table};
	$opt->{path} = $self->filePath unless $opt->{path};
	$opt->{sort} = 0 unless $opt->{sort};
	$opt->{id_record} = $self->R->F->{id_record} unless $opt->{id_record};

	# File name
	my $name = $self->R->F->{'_files'};

	# File extension
	my $ext = $name;
	$ext =~ s/[^.]+\.(.*)/$1/gi;

	# The name of the uploaded file
	my $fname;

	# If the extension was found
	if ($ext ne $name) {
		$self->connectDB;

		# Source file
		$opt->{file} = $self->R->F->{files};

		# Add file info to a database
		my $id = $self->insert(
			{
				id_record => $opt->{id_record},
				tbl => $opt->{table},
				ext => $ext,
				sort => $opt->{sort},
				file_size => -s $opt->{file}
			},
			$self->tableFile,
			'id'
		);

		# The name of the uploaded file
		$opt->{name} = 'f_'.$opt->{id_record}.'_'.$id;

		# Upload the file to the server
		$fname = $self->uploadFile($opt);
	}

	# The full name of the uploaded file
	return $fname.'.'.$ext;
}

=nd
Method: fileDelete
	A method which removes the file from the database and the server.

Parameters:
	$opt->{id_record}	- id записи, у которой удаляется файл
	$opt->{id}			- id файла в таблице file
	$opt->{path}		- путь к папке, в которой лежит файл
=cut
sub fileDelete {
	my ($self, $opt) = @_;
	return unless $opt;

	# Удаляем файлы из каталога
	my $fname = 'f_'.$opt->{id_record}.'_'.$opt->{id};
	my $path = $opt->{path};
	`rm "$path${fname}."*`;
}

1;