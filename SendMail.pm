package Tatooine::SendMail;

=nd
Package: SendRequest
        Модуль для отправки сообщений на электронную почту.
=cut

use strict;
use warnings;
use utf8;

use MIME::Base64;
use Encode;		# модуль для перекодирования строк
use MIME::Lite;
use base qw /Exporter Tatooine::Base /;
our @EXPORT = qw(send_mail);

=nd
Method: send_mail
	Отправка письма пользователю
	
Parameters:
	$subj  - тема письма
	$flow  - Поток даных для шаблона	
	$tpl   - шаблон отправляемого письма
=cut

sub send_mail {
	my ($subj, $flow, $tpl) = @_;

	# Генерим шаблон и сохраняем результат в переменную
	my $data;
	my $tt = Template->new({
		INCLUDE_PATH => "$ENV{ DOCUMENT_ROOT }/../template/",
		INTERPOLATE  => 0,
		RELATIVE => 1,
		ENCODING => 'utf8',
	});
	$tt->process(Tatooine::Base::T->{mail}{$tpl}, $flow, \$data) or systemError('Template not found');
	
	# Получаем сообщение
	$subj = Encode::encode("utf8", Tatooine::Base::M->{mail}{$subj});
	$data = Encode::encode("utf8", $data);

	# Перекодируем данные в кодировку KOI8-R
	Encode::from_to($subj, 'utf8', Tatooine::Base::C->{mail}{charset});
	Encode::from_to($data, 'utf8', Tatooine::Base::C->{mail}{charset});

	# Объект MIME::Lite
	my $msg = MIME::Lite->new(
			To      => $flow->{email},
			From 	=> Tatooine::Base::C->{mail}{from},
			Subject => $subj,
			Type    => 'HTML',
			Data    => $data
	);
	
	# Кодировка письма
	$msg->attr("content-type.charset" => Tatooine::Base::C->{mail}{charset});

	# Отправляем письмо
	$msg->send;
}

1;
