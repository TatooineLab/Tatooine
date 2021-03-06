package Tatooine::Router;
use base qw /Tatooine::Base/;

=nd
Package: Tatooine::Router
	Регистирирует действия, выбирает нужные и исполняет их в правильной последовательности.
=cut

use strict;
use warnings;

use utf8;
use bytes;

use CGI;
use CGI::Fast;
use Template;
use Tatooine::Error;
use FindBin;

=nd
Method: new
	Конструктор. Создает объект модуля.
=cut
sub new {
	my ($class, $add_attr) = @_;
	# Проверяем атрибуты потоска
	$add_attr = {} unless $add_attr;

	my $docroot_path = $FindBin::Bin;
	$docroot_path =~ s/^(.*public_html).*/$1/;

	my $tt = Template->new({
		INCLUDE_PATH => $docroot_path."/../template/",
		INTERPOLATE  => 0,
		RELATIVE => 1,
		ENCODING => 'utf8',
	});

	# Заполняем поля объекта
	my $self = bless {
		action 		=> {},		# Действия
		select_actions	=> undef,	# Выбранные действия
		active_actions	=> [],		# Действия которые будут выполнены
		flow		=> {},		# Поток
		cgi		=> undef,	# Объект CGI
		template	=> undef,	# Шаблон
		dbh		=> undef,	# Дескриптор БД
		tt => $tt,
		%{$add_attr}			# Дополнительные атрибуты
	}, $class;
}

=nd
Method: registerAction($name_action, $action)
	Регистрация действии.

See Also:
	selectActions
=cut
sub registerAction {
	my ($self, $name, $action) = @_;
	$self->{action}->{$name} = $action;
}

=nd
Method: selectActions(ref @{$actions})
	Выбор нужный действии. Принимает ссылку на массив.
=cut
sub selectActions {
	my ($self, $actions) = @_;
	$self->{select_actions} = $actions;
}

=nd
Method: nextAction
	Возвращает действие из списка "активных".
=cut
sub nextAction {
	my $self = shift;
	pop @{$self->{active_actions}};
}

=nd
Method: listen
	В зависимости от конфигурации запускает listen либо для FCGI, либо для CGI
=cut
sub listen {
	my $self = shift;

	if ($self->C->{server} and $self->C->{server} eq 'CGI') {
		$self->listen_cgi;
	} else {
		$self->listen_fcgi;
	}
}

=nd
Method: listen_fcgi
	Выполняет действия (для FastCGI)
=cut
sub listen_fcgi {
	my $self = shift;
	while ($self->{cgi} = CGI::Fast->new) {
		$CGI::PARAM_UTF8 = 1;
		for my $name ($self->CGI->param) {
			if($name =~ /^arr_/) {
				push @{$self->{flow}{$name}}, $self->CGI->param($name);
			} else {
				$self->{flow}{$name} = $self->CGI->param($name)
			}
		}
		# Получаем имя действие(я) которое(ые) нужно выполнить
		push @{$self->{active_actions}}, $self->{select_actions}->($self);
		# Выполняем действия
		while(my $name = $self->nextAction) {
			warn $name;
			# Выходим из цикла
			if($name eq 'ACCESS_DENIEDED' or $self->RA($name) eq 'STOP') {
				$self->out;
				last;
			}
		}
		$self->_clean;
	}
}

=nd
Method: listen_cgi
	Выполняет действия (для CGI)
=cut
sub listen_cgi {
	my $self = shift;
	# Создаем обьект CGI
	$self->CGI(new CGI);
	$CGI::PARAM_UTF8 = 1;
	for my $name ($self->CGI->param) {	
		if($name =~ /^arr_/) {
			push @{$self->{flow}{$name}}, $self->CGI->param($name);
		} else {
			$self->{flow}{$name} = $self->CGI->param($name)
		}
	}
	#Получаем имя действие(я) которое(ые) нужно выполнить
	push @{$self->{active_actions}}, $self->{select_actions}->($self);
	#Выполняем действия
 	while(my $name = $self->nextAction) {
		warn $name;
		# Выходим из цикла
		if($self->RA($name) eq 'STOP') {
			$self->out;
			last;
		}
	}
}

=nd
Method: out
	Вывод данных в браузер.
=cut
sub out {
	my $self = shift;
	# Если шаблон задан, выставляем его.
	if ($self->{template}) {
		print "Content-type: text/html; charset=UTF-8\n\n";

		my $data;
		$self->{tt}->process($self->{template}, $self->F, \$data) or systemError($self->{tt}->error());
		print $data;
	}
};

=nd
Method: setTpl($name_tpl)
	Устанавливает имя шаблона для публичной части. Принимает имя шаблона.
=cut
sub setPubTpl {
	my ($self, $tpl) = @_;
	#Выставляем шаблон, данные беруться из конфига
	$self->{template} = Tatooine::Base::T->{public}{$tpl};
}

=nd
Method: setAdmTpl($name_tpl)
	Устанавливает имя шаблона для админской части. Принимает имя шаблона.
=cut
sub setAdmTpl {
	my ($self, $tpl) = @_;
	#Выставляем шаблон, данные беруться из конфига
	$self->{template} = Tatooine::Base::T->{admin}{$tpl};
}

=nd
Method: setSystemTpl($name_tpl)
	Устанавливает системные шаблоны. Принимает имя шаблона.
=cut
sub setSystemTpl {
	my ($self, $tpl) = @_;
	#Выставляем шаблон, данные беруться из конфига
	$self->{template} = Tatooine::Base::T->{system}{$tpl};
}

=nd
Method: CGI
	Метод доступа к данным структуры объекта. Доступ к полю cgi

See Also:
	RA
=cut
sub CGI {
	my $self = shift;
	if (@_) { $self->{cgi} = shift }
	$self->{cgi};
}

=nd
Method: RA($name_action)
	Метод доступа к данным структуры объекта. Доступ на выполнение действия.

See Also:
	CGI
=cut
sub RA {
	my ($self, $name) = @_;
	if ($self->{action}{$name}) {
		$self->{action}{$name}{do}->($self);
	} else {
		warn "Script does not have action $name";
	}
}

=nd

Method: F
	Метод доступа к потоку вывода сервера

See Also:
	CGI RA
=cut
sub F { shift->{flow} }

=nd
Method: dbh
	Метод доступа к дескриптору БД

=cut
sub dbh { shift->{dbh} }

=nd
Method: _clean
	Деструктор
=cut

sub _clean {
	my $self = shift;

	# Чистим поток
	$self->{flow} = {};
	@{$self->{active_actions}} = ();

	# Отсоединяемся от базы, если подключены
	if ($self->dbh and $self->dbh->ping) {
		$self->dbh->disconnect or warn $self->dbh->errstr;
	}

	undef $self->{cgi};
	undef $self->{dbh};
	undef $self->{select_action};

	# Чистим стек ошибок
	clearErrors();
}

1;
