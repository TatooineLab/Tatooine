package Tatooine::SendMail;

=nd
Package: SendRequest
        Модуль для отправки сообщений на электронную почту.
=cut

use strict;
use warnings;

use Net::SMTP;
use MIME::Base64;
use Encode;		# модуль для перекодирования строк
use MIME::Lite;

use base qw(Exporter);
our @EXPORT = qw(mail compose_msg send_mail);



=nd
Function: mail

	Процедура отправки письма на почту.

   	Parameters:

        	$msg - отправляемое письмо;
		$server - имя домена.
=cut
sub mail {
	my ($msg, $server) = @_;
	
	# Интерпретировать сообщение для получения адреса отправителя и получателя
	my ($header, $body) = split /\n\n/,$msg,2;
	return warn "No header" unless $header && $body;
	
	# Соединить строки продолжения
	$header =~ s/\n\s+/ /gm;
	
	# Разбираем поля заголовка
	my (%fields) = $header =~ /([\w-]+):\s+(.+)$/mg;
	# Адрес отправитля
	my $from = $fields{From}
		   or die "no From field";
	# Адрес получателя
	my @to = split /\s*,\s*/,$fields{To}
		 or die "no To field";
	push @to, split /\s*,\S*/, $fields{Cc} if $fields{Cc};
	
	# Открыть сеанс связи с сервером
	my $smtp = Net::SMTP->new($server, Port=>25, Hello=>'nic.mail.ru', Timeout=>160, Debug=>1)
		   or die "couldn't open server";
	
	# Авторизация отправителя
	$smtp->datasend("AUTH LOGIN\n");
	$smtp->response();

	#  Имя пользователя почты
	$smtp->datasend(encode_base64('ddulin@alaskartech.com') );
	$smtp->response();

	#  Пароль от почты
	$smtp->datasend(encode_base64('34spedj') );
	$smtp->response();
	# Отправляем письмо
	$smtp->mail($from)
		   or die $smtp->message;
	# Проверяем, отправилось ли оно или нет
	my @ok = $smtp->recipient(@to,{SkipBad=>1})
		   or die $smtp->message;
	warn $smtp->message unless @ok == @to;
	$smtp->data($msg)
		   or die $smtp->message;
	# Закрываем сеанс связи с сервером
	$smtp->quit;
}

=nd
Function: compose_msg

	Функция составление письма

   	Parameters:

        	$fields  - Поля для составление сообщения
		$script  - объект скрипта
=cut

sub compose_msg {
	my $fields = shift;
	# Cообщение для отправки на почту администратора
	my $adminmail = 'skostin@alaskartech.com'; 	# почта администратора
	
	my $msg= qq{From: admin <$adminmail>\nTo: <$fields->{TO}>\nSubject: $fields->{SUBJ} \nContent-Type: text/plain; charset=KOI8-R;\n\n$fields->{TEXT}};
	
	# Перекодируем сообщение в кодировку windows-1251(cp1251)
	Encode::from_to($msg, 'utf8', 'KOI8-R');

	return $msg;
}

sub send_mail {
	# Объект MIME::Lite
	my $msg = shift;

	$msg->add(
		From 	=> 'info@alaskartech.com'
	);

	# Кодировка письма
	$msg->attr("content-type.charset" => "KOI8-R");

	my $user = 'info@alaskartech.com';
	my $pass = 'nv36eB';
	# Отправляем письмо
	$msg->send('smtp','mail.nic.ru', AuthUser=>$user, AuthPass=>$pass );
}

1;
