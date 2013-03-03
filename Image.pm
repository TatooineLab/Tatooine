package Tatooine::Image;


=nd
Package: Image
	Модуль для работы с изображениями.
=cut

use strict;
use warnings;

use Image::Magick; 	# модуль для обработки изображений
use base qw(Object);	# базовый модуль для всех объектов
use Error;		# модуль ошибок

my $img_table = 'image';

=nd
Method: getImageList
	Список изображений для записи

Parameters:
	$opt - хеш с параметрами
=cut
sub getImageList {
	my ($self, $opt) = @_;
	$opt = {} unless $opt;

	# Идентификатор записи, для которой достаются картинки
	my $id = $opt->{id_record} || $self->S->F->{id};
	# Таблица, в которой находится запись
	my $table = $opt->{table} || $self->table;

	# Если нет подключения к базе, то коннектимся
	if (!$self->S->dbh or !$self->S->dbh->ping) {
		$self->S->connectDB;
	}

	$self->getRecord({
			table => $img_table,
			where => {
				id_record => $id,
				tbl => $table
			},
			flow_type => 'hashref_array'
	});
}

=nd
Method: uploadImage
	Загружает картинку на сервер.

Parameters:
	$opt->{file}		- исходный файл
	$opt->{id_record}	- id записи, для которой грузится файл
	$opt->{table}		- имя таблицы, для которой загружается изображение
	$opt->{path}		- путь к папке,в которую будет загружен файл
=cut
sub uploadImage {
	my ($self, $opt) = @_;
	$opt = {} unless $opt;

	$opt->{table} = $self->table unless $opt->{table};
	$opt->{path} = $self->filePath unless $opt->{path};
	$opt->{sort} = 0 unless $opt->{sort};

	# выделяем имя файла из параметра
	my ($name) = $opt->{file} =~ m#([^\\/:]+)$#;

	# Получаем расширение картинки
	my $ext = $name;
	$ext =~ s/.*((png)|(gif)|(jpg))$/$1/gi;

	# Имя загруженного файла
	my $fname;

	# Если расширение соответствует заданным
	if ($ext ne $name) {
		# Если нет подключения к базе, то коннектимся
		if (!$self->S->dbh or !$self->S->dbh->ping) {
			$self->S->connectDB;
		}


		# Добавляем информацию о файле в базу
		my $id = $self->addRecord(
			{
				id_record => $opt->{id_record},
				tbl => $opt->{table},
				ext => $ext,
				sort => $opt->{sort}
			},
			$img_table,
			'id'
		);

		# Имя файла
		$fname = $opt->{id_record}.'_'.$id;

		# Загружаем файл на сервер
		$self->uploadFile($opt->{file}, $fname, $opt->{path});
	}

	return $fname.'.'.$ext;
}

=nd
Method: deleteImage
	Метод, который удаляет картинку

Parameters:
	$opt->{name}		- название файла
	$opt->{id_record}	- id записи, у которой удаляется файл
	$opt->{id}		- id файла в таблице image
	$opt->{path}		- путь к папке,в которую будет загружен файл
=cut
sub deleteImage {
	my ($self, $opt) = @_;
	$opt = {} unless $opt;

	## Значения по умолчанию
	if ($opt->{name}) {
		$opt->{name} =~  /^((\d+)_(\d+))/;
		$opt->{id} = $3 unless $opt->{id};
		$opt->{id_record} = $2 unless $opt->{id_record};
	}
	$opt->{path} = $self->filePath unless $opt->{path};

	# Если нет подключения к базе, то коннектимся
	if (!$self->S->dbh or !$self->S->dbh->ping) {
		$self->S->connectDB;
	}

	# Удаляем запись из базы
	if ($opt->{id}){
		$self->deleteRecord({ id => $opt->{id} }, $img_table);
	# Удаление всех записей
	} else {
		$self->deleteRecord({ id_record => $opt->{id_record} }, $img_table);
	}

	# Удаляем файлы из каталога
	my $fname = $opt->{id} ? $opt->{id_record}.'_'.$opt->{id} : $opt->{id_record};
	my $path = $opt->{path};
	`rm "$path${fname}."*`;
	`rm "$path${fname}_"*`;
}

=nd
Method: resizeImage
	Изменяет размер изображения.

Parameters:
	$picname  -	имя файла изображения, которую нужно изменить.
	$path 	  -	путь к папке, в которой лежит изображение. По умолчанию берётся из функции filePath.

See Also:
	filePath
=cut
sub resizeImage {
	# Получаем входные данные.
	my ($self, $picname, $path) = @_;
	my ($image, $x);
	# Cоздаём объект для работы с изображением
	$image = Image::Magick->new;
	# Открываем файл
	$x = $image->Read($path.$picname);
	# определяем ширину и высоту изображения
	my ($ox,$oy) = $image->Get('base-columns','base-rows');
	# Если изображение прямоугольное горизонтальное
	if($ox>$oy){
		# Вычисляем откуда нам резать
		my $nnx=int(($ox-$oy)/2);
		# Задаем откуда будем резать
		$image->Crop(x=>$nnx, y=>0);
		# С того места вырезаем квадрат
		$image->Crop($oy.'x'.$oy);
	# Если изображение прямоугольное вертикальное, либо квадратное
	} else {
		my $nny=int(($oy-$ox)/2);
		#Задаем откуда будем резать
		$image->Crop(x=>0, y=>$nny);
		#С того места вырезаем квадрат
		$image->Crop($ox.'x'.$ox);
	}
	# Делаем resize (изменения размера)
	$image->Resize(width=>170, height=>170);
	# Сохраняем изображение.
	$x = $image->Write($path.$picname);
}


=nd
Method: resizeImageSize
	Изменяет размер изображения до заданного размера

Parameters:
	$picname  -	имя файла изображения, которое нужно изменить.
	$path 	  -	путь к папке, в которой лежит изображение. По умолчанию берётся из функции filePath.
	$size	  -	хеш, который хранит размеры изображения

See Also:
	filePath
=cut
sub resizeImageSize {
	# Получаем входные данные.
	my ($self, $picname, $path, $size, $param) = @_;
	my ($image, $x);

	# Получаем расширение файла
	my $ext=$picname;
	$ext =~s /.*((png)|(gif)|(jpg))$/$1/gi;
	# Получаем имя файла
	my $fname = $picname;
	$fname =~ s/.$ext//;
	# Cоздаём объект для работы с изображением
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

	warn $path.$fname."_".$size->{width}."x".$size->{height}.".".$ext;
	warn $ENV{DOCUMENT_ROOT}.'/img/watermark/watermark_'.$size->{width}.'x'.$size->{height}.'.png';

	$img->Composite(image=>$layer,compose=>'Atop', x=>0, y=>0);

	$img->Write( $path.$fname."_".$size->{width}."x".$size->{height}.".".$ext );
}
