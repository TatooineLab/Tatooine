package Tatooine::Router;
use base qw /Tatooine::Base/;

=nd
Package: Tatooine::Router
	Регистирирует действия, выбирает нужные и исполняет их в правильной последовательности.
=cut

use strict;
use warnings;

use utf8;

use CGI;
use CGI::Fast;
use Template;
use Tatooine::Error;

=nd
Method: new
	Конструктор. Создает объект модуля.
=cut
sub new {
	my ($class, $add_attr) = @_;
	# Проверяем атрибуты потоска
	$add_attr = {} unless $add_attr;
	# Заполняем поля объекта
	my $self = bless {
		action 		=> {},		# Действия
		select_actions	=> undef,	# Выбранные действия
		active_actions	=> [],		# Действия которые будут выполнены
		flow		=> {},		# Поток
		cgi		=> undef,	# Объект CGI
		template	=> undef,	# Шаблон
		dbh		=> undef,	# Дескриптор БД
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
	Выполняет действия
=cut
sub listen {
	my $self = shift;
	#Создаем обьект CGI
# 	$self->R(new CGI);
	#Вытаскиваем CGI
#	$self->{flow}{$_} = $self->R->param($_) foreach $self->R->param;
	while ($self->R(CGI::Fast->new)) {
		$CGI::PARAM_UTF8 = 1;
		for my $name ($self->R->param) {
			if($name =~ /arr/) {
				push @{$self->{flow}{$name}}, $self->R->param($name);
			} else {
				$self->{flow}{$name} = $self->R->param($name)
			}
		}
		#Получаем имя действие(я) которое(ые) нужно выполнить
		push @{$self->{active_actions}}, $self->{select_actions}->($self);
		#Выполняем действия
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
Method: out
	Вывод данных в браузер.
=cut
sub out {
	my $self = shift;
	print "Content-type: text/html; charset=UTF-8\n\n";
	# Если шаблон задан, выставляем его.
	if ($self->{template}) {	
		my $tt = Template->new({
			INCLUDE_PATH => "$ENV{ DOCUMENT_ROOT }/../template/",
			INTERPOLATE  => 0,
			RELATIVE => 1,
		#	RECURSION =>1,
		});
		$tt->process($self->{template}, $self->F) or systemError('Template not found');
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
Method: R
	Метод доступа к данным структуры объекта. Доступ к полю cgi

See Also:
	RA
=cut
sub R {
	my $self = shift;
	if (@_) { $self->{cgi} = shift }
	$self->{cgi};
}

=nd
Method: RA($name_action)
	Метод доступа к данным структуры объекта. Доступ на выполнение действия.

See Also:
	R
=cut
sub RA {
	my ($self, $name) = @_;
	$self->{action}{$name}{do}->($self);
}

=nd

Method: F
	Метод доступа к потоку вывода сервера

See Also:
	R RA
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

	# Чистим стек ошибок
	clearErrors();
}

1;
