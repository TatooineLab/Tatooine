package Tatooine::Base;

=nd
Package: Tatooine::Base
	Базовый класс проекта
=cut

use strict;
use warnings;

use Tatooine::Conf;
use Tatooine::Error;

=nd
Method: new($script_object)
	Конструктор

Parameters:
	$script - объект скрипта
=cut
sub new {
	my ($class, $attr_child) = @_;
	# Проверяем атрибуты потоска
	$attr_child = {} unless $attr_child;

	# Заполняем поля объекта
	my $self = bless{
		%{$attr_child}
	}, $class;
	# Ссылка на самого себя
	$self->{moduleObject} = $self;
}

=nd
Method: R
	Метод доступа к объекту Router
=cut
sub R { shift->{router} }

=nd
Method: C
	Метод доступа ко глобальному конфигу проекта
=cut
sub C { $Tatooine::Conf::DATA }

=nd
Method: T
	Метод доступа к конфигу шаблонов
=cut
sub T { $Tatooine::Conf::TPL }

=nd
Method: table
	Метод доступа к названию таблицы, с которой работает модуль
=cut
sub table { shift->{db}{table} }

=nd
Method: Prefix
	Метод доступа к префиксу действий модуля

See Also:
	mO
=cut
sub Prefix { shift->{action_prefix} }

=nd
Method: mO
	Метод доступа к объекту модуля

See Also:
	mN
=cut
sub mO { shift->{moduleObject} }

1;