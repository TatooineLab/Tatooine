package Tatooine::Conf;

=nd
Package: Tatooine::Config
	Работа с глобальным конфигом проекта

	Читаем глобальный конфиг из <CONFPATH>.
=cut

use strict;
use warnings;

use utf8;

use Tatooine::Error;
use XML::Simple;

=begin nd
Constant: CONFPATH
	Путь к глобльному конфигу проекта

=cut

# $INC[0] - содержит путь до папки lib. От нее идем к конфигурационным файлам
use constant {
	CONFPATH => $INC[0].'/../conf/global.xml',
	TEMPLATEPATH => $INC[0].'/../conf/template.xml',
};

use vars qw/ $DATA $TPL /;

# Читаем данные из конфига
my $simple = XML::Simple->new();
# Получаем данные глобального конфига
$DATA = $simple->XMLin(CONFPATH) or systemErorr('Template config file does not exist');
# Получаем конфига шаблонов
$TPL = $simple->XMLin(TEMPLATEPATH) or systemErorr('Template config file does not exist');

1;