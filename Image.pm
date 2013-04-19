package Tatooine::Image;

=nd
Package: Image
	A class for working with images.
=cut

use strict;
use warnings;

use utf8;

use base qw / Tatooine::File /;

use Image::Magick;		# ImageMagick is a software suite to create, edit, compose, or convert bitmap images.
						# http://www.imagemagick.org/

use Tatooine::Error;	# Class for handling errors.
use JSON;

=nd
Method: registerImageActions
	The method of recording actions for the module.
=cut
sub registerImageActions {
	my $self = shift;
	my $router = $self->{router};

	# Главная страница
	$router->registerAction($self->Prefix.'_IMAGE_MAIN' => { do => sub {
			my $S = shift;

			$self->mO->setImageTpl('MAIN');
			return 'STOP';
		}
	});

	# Вывод списка записей
	$router->registerAction($self->Prefix.'_IMAGE_LIST' => { do => sub {
			my $S = shift;
			$self->mO->connectDB;

			# Получаем список записей
			$S->F->{image_list} = $self->mO->getImageList;

			$self->mO->setImageTpl('LIST');
			return 'STOP';
		}
	});

	# Добавление/редактирование записи
	$router->registerAction($self->Prefix.'_IMAGE_UPLOAD' => { do => sub {
			my $S = shift;

			# Загружаем файл на сервер
 			my $file_name = $self->mO->imageUpload;

			# Формируем сообщение
			$S->F->{message} = "The file was successfully uploaded.";

			# Преобразуем сообщение в JSON формат
			$S->F->{data} = to_json( $S->F->{message}, {allow_nonref => 1} );
			$S->setSystemTpl('JSON');
			return 'STOP';
		}
	});

	# Форма добавления/редактирования записи
	$router->registerAction($self->Prefix.'_IMAGE_FORM' => { do => sub {
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

			$self->mO->setImageTpl('FORM');
			return 'STOP';
		}
	});

	# Добавление/редактирование записи
	$router->registerAction($self->Prefix.'_IMAGE_SAVE' => { do => sub {
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
				$S->F->{message} = "Image is saved.";
			}

			# Преобразуем сообщение в JSON формат
			$S->F->{data} = to_json( $S->F->{message}, {allow_nonref => 1} );
			$S->setSystemTpl('JSON');
			return 'STOP';
		}
	});

	# Окно удаления записи
	$router->registerAction($self->Prefix.'_IMAGE_WND_DELETE' => { do => sub {
			my $S = shift;

			$self->mO->setImageTpl('WND_DELETE');
			return 'STOP';
		}
	});

	# Удалить запись
	$router->registerAction($self->Prefix.'_IMAGE_DELETE' => { do => sub {
			my $S = shift;
			$self->connectDB;

			if ($self->R->F->{id}){
				# Get image info
				my $img = $self->getRecord({
					table => $self->tableImage,
					where => {
						id => $self->R->F->{id}
					}
				});

				# Delete record from database
				$self->delete({ id => $self->R->F->{id} }, $self->tableImage);

				# Delete image from path
				$self->mO->imageDelete({
					id => $img->{id},
					id_record => $img->{id_record},
					path => $self->filePath
				}) if $img;

				# Формируем сообщение
				$S->F->{message}{class} = 'success';
				push @{$S->F->{message}{msg}}, "Image is deleted.";
			} else {
				# Формируем сообщение
				$S->F->{message}{class} = 'error';
				push @{$S->F->{message}{msg}}, "Error. Image is not deleted.";
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
sub selectImageActions {
	my $self = shift;
	my $R = $self->{router};
	my @act;

	push @act, $self->Prefix.'_IMAGE_MAIN'			if $R->F->{image_main};
	push @act, $self->Prefix.'_IMAGE_UPLOAD'		if $R->F->{image_upload};
	push @act, $self->Prefix.'_IMAGE_LIST'			if $R->F->{image_list};
	push @act, $self->Prefix.'_IMAGE_WND_DELETE' 	if $R->F->{image_wnd_delete};
	push @act, $self->Prefix.'_IMAGE_DELETE' 		if $R->F->{image_delete};

	push @act, $self->Prefix.'_IMAGE_FORM'			if $R->F->{image_form};
	push @act, $self->Prefix.'_IMAGE_SAVE'			if $R->F->{image_save};

	return @act;
}

=nd
Method: setImageTpl($name_tpl)
	The method that sets the template.

Parameters:
	$name_tpl - template name
=cut
sub setImageTpl {
	my ($self, $name_tpl) = @_;
	# Set the template, the data are taken from the config file
	$self->R->{template} = $self->T->{system}{image}{$name_tpl};
}

=nd
Method: tableImage
	The method of access to the name of the table you are working on a module.
=cut
sub tableImage { shift->{db}{image_table} }

=nd
Method: getImageList
	The method for getting the image list from database.

Parameters:
	$opt - hash with parameters
=cut
sub getImageList {
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
			table => $self->tableImage,
			where => {
				id_record => $id,
				tbl => $table
			},
			flow_type => 'hashref_array'
	});
}

=nd
Method: imageUpload
	The method for uploading image to a server.

Parameters:
	$opt->{file}		- source file
	$opt->{id_record}	- The ID of the record for which the file is uploaded.
	$opt->{table}		- Name of the table on which an image is uploaded.
	$opt->{path}		- The path to the folder in which the file will be uploaded.
=cut
sub imageUpload {
	my ($self, $opt) = @_;
	$opt = {} unless $opt;

	$opt->{table} = $self->table unless $opt->{table};
	$opt->{path} = $self->filePath unless $opt->{path};
	$opt->{sort} = 0 unless $opt->{sort};
	$opt->{id_record} = $self->R->F->{id_record} unless $opt->{id_record};

	# File name
	my $name = $self->R->F->{'_pictures'};

	# File extension
	my $ext = $name;
	$ext =~ s/.*((png)|(gif)|(jpg))$/$1/gi;

	# The name of the uploaded file
	my $fname;

	# If the extension matches the specified png, gif, jpg
	if ($ext ne $name) {
		$self->connectDB;

		# Source file
		$opt->{file} = $self->R->F->{pictures};

		# Add image info to a database
		my $id = $self->insert(
			{
				id_record => $opt->{id_record},
				tbl => $opt->{table},
				ext => $ext,
				sort => $opt->{sort},
				file_size => -s $opt->{file}
			},
			$self->tableImage,
			'id'
		);

		# The name of the uploaded file
		$opt->{name} = $opt->{id_record}.'_'.$id;

		# Upload the file to the server
		$fname = $self->uploadFile($opt);

		# Get image sizes from database
		my $size = $self->getRecord({
			table => 'image_setting',
			flow_type => 'hashref_array'
		});

		# Resize images
		foreach my $i (@{$size}) {
			$self->resizeImage({
				picname => $fname,
				size => {
					width => $i->{width},
					height => $i->{height}
				}
			});
		}
	}

	# The full name of the uploaded file
	return $fname.'.'.$ext;
}

=nd
Method: imageDelete
	A method which removes the image from the database and the server.

Parameters:
	$opt->{id_record}	- id записи, у которой удаляется файл
	$opt->{id}			- id файла в таблице image
	$opt->{path}		- путь к папке, в которой лежит файл
=cut
sub imageDelete {
	my ($self, $opt) = @_;
	return unless $opt;

	# Удаляем файлы из каталога
	my $fname = $opt->{id_record}.'_'.$opt->{id};
	my $path = $opt->{path};
	`rm "$path${fname}."*`;
	`rm "$path${fname}_"*`;
}

=nd
Method: resizeImage
	Изменяет размер изображения до заданного размера

Parameters:
	$opt->{picname}	-	имя файла изображения, которое нужно изменить.
	$opt->{path}	-	путь к папке, в которой лежит изображение. По умолчанию берётся из функции filePath.
	$opt->{size}	-	хеш, который хранит размеры изображения

See Also:
	filePath
=cut
sub resizeImage {
	# Получаем входные данные.
	my ($self, $opt) = @_;
	my ($image, $x, $picname, $path, $size, $param);

	$picname = $opt->{picname};
	$path = $opt->{path} || $self->filePath;
	$size = $opt->{size};
	$param = $opt->{param};

	# File extension
	my $ext=$picname;
	$ext =~s /.*((png)|(gif)|(jpg))$/$1/gi;

	# File name
	my $fname = $picname;
	$fname =~ s/.$ext//;

	# Create an object for working with images
	$image = Image::Magick->new;

	# Открываем файл
	$x = $image->Read($path.$picname);
	# определяем ширину и высоту изображения
	my ($ox,$oy) = $image->Get('base-columns','base-rows');

	my ($prop_x, $prop_y, $nnx, $nny);
	# Пропорционально увеличиваем высоту и ширину, если картинка маленькая
	if($size->{width}>$ox or $size->{height}>$oy){
		if($size->{width}>$ox){
			$oy *= $size->{width}/$ox;
			$ox = $size->{width};
		}
		if($size->{height}>$oy){
			$ox *= $size->{height}/$oy;
			$oy = $size->{height};
		}
		$oy = int($oy);
		$ox = int($ox);
		# Делаем resize (изменения размера)
		$image->Resize(width=>$ox, height=>$oy);

		# Вычисляем пропорции
		if ($ox == $size->{width}){
			$prop_x = $ox;
			$prop_y = $size->{height};
			$nnx = 0;
			$nny = int(($oy-$prop_y)/2);
			# Вырезаем изображение
			$image->Crop(width=>$prop_x, height=>$prop_y, x=>$nnx, y=>0);
		} elsif ($oy == $size->{height}) {
			$prop_y = $oy;
			$prop_x = $size->{width};
			$nnx = int(($ox-$prop_x)/2);
			$nny = 0;
			# Вырезаем изображение
			$image->Crop(width=>$prop_x, height=>$prop_y, x=>$nnx, y=>0);
		}
	# Пропорционально уменьшаем картинку, если она большая
	} else {
		## Вычисляем пропорции
		if($size->{width}>$size->{height}){
			my $k = $ox/$size->{width};

			if($oy/$k < $size->{height}){
				$k = $oy/$size->{height};
				$prop_x = $k * $size->{width};
				$prop_y = $k * $size->{height};
				# Вычисляем откуда нам резать по X
				$nnx=int(($ox-$prop_x)/2);
				$nny=0;
				# Вырезаем изображение
				$image->Crop(width=>$prop_x, height=>$prop_y, x=>$nnx, y=>0);
			} else {
				$prop_y = $k * $size->{height};
				$prop_x = $k * $size->{width};
				# Вычисляем откуда нам резать по Y
				$nnx=0;
				$nny=int(($oy-$prop_y)/2);
				# Вырезаем изображение
				$image->Crop(width=>$prop_x, height=>$prop_y, x=>$nnx, y=>0);
			}

		} else {
			my $k = $oy/$size->{height};

			if($ox/$k < $size->{width}){
				$k = $ox/$size->{width};
				$prop_y = $k * $size->{height};
				$prop_x = $k * $size->{width};
				# Вычисляем откуда нам резать по Y
				$nnx=0;
				$nny=int(($oy-$prop_y)/2);
				# Вырезаем изображение
				$image->Crop(width=>$prop_x, height=>$prop_y, x=>$nnx, y=>0);
			} else {
				$prop_x = $k * $size->{width};
				$prop_y = $k * $size->{height};
				# Вычисляем откуда нам резать по X
				$nnx=int(($ox-$prop_x)/2);
				$nny=0;
				# Вырезаем изображение
				$image->Crop(width=>$prop_x, height=>$prop_y, x=>$nnx, y=>0);
			}
		}
		# Вырезаем изображение
		$image->Resize(width=>int($size->{width}), height=>int($size->{height}));
	}
	# Сохраняем изображение.
	my $f;
	if ($param and $param eq 'edit'){
		$x = $image->Write($path.$fname.".".$ext);
		$f = $path.$fname.".".$ext;
	} else {
		$x = $image->Write($path.$fname."_".$size->{width}."x".$size->{height}.".".$ext);
		$f = $path.$fname."_".$size->{width}."x".$size->{height}.".".$ext;
	}
}

sub addWatermark {
	# Получаем входные данные.
	my ($self, $picname, $path, $size) = @_;

	my $img = Image::Magick->new;
	my $layer = Image::Magick->new;

	# Получаем расширение файла
	my $ext=$picname;
	$ext =~s /.*((png)|(gif)|(jpg))$/$1/gi;
	# Получаем имя файла
	my $fname = $picname;
	$fname =~ s/.$ext//;

	$img->Read( $path.$fname."_".$size->{width}."x".$size->{height}.".".$ext );
	$layer->Read( $ENV{DOCUMENT_ROOT}.'/img/watermark/watermark_'.$size->{width}.'x'.$size->{height}.'.png');

	$img->Composite(image=>$layer,compose=>'Atop', x=>0, y=>0);

	$img->Write( $path.$fname."_".$size->{width}."x".$size->{height}.".".$ext );
}

1;
