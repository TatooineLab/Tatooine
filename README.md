# Tatooine

Tatooine - web-фреймворк, написанный на языке Perl.

## Начало работы
В папке public_html необходимо создать скрипт index.html:

```perl
#! /usr/bin/perl

use strict;
use warnings;
use utf8;

use lib '../lib';

use Tatooine::Router;

# Создаем объект для управления действиями
my $router = Tatooine::Router->new();

# Регистрируем действие для вывода главной страницы
$router->registerAction(MAIN => { do => sub {
  	my $S = shift; # ссылка на объект $router (сокращенно от self)

    # В поток передаём необходимые данные для вывода на странице
    $S->F->{output_data} = 'test data';

    # Выставляем шаблон для публичной части сайта
    $S->setPubTpl('MAIN');
    # Ключевое слово для завершения поиска подходящего действия 
    # (необходимо указывать в каждом действии)
    return 'STOP';
	}
});

# Выбираем действие(я) в зависимости от пришедших параметров CGI
$router->selectActions ( sub {
  	my $S = shift;
  	my @act;
  
    # По умолчанию для отображения страницы всегда выбирается действие MAIN
    push @act, 'MAIN';
  
  	return @act;
});

$router->listen;
```

## Создание модуля
Вы можете создать модуль, например, модуль для работы со статьями - Article. Для этого создадите в папке lib/ файл Article.pm:

```perl
package Article;

=nd
Package: Article
  Модуль для работы со статьями
=cut

use strict;
use warnings;

use Error;
use Tatooine::Validator;
# Наследуем методы для работы со стандартными действиями (сохранение, вывод, удаление)
# и для работы с базой данных
use parent qw(Tatooine::DB Tatooine::BaseActions);

=nd
Method: new
  Конструктор
=cut
sub new {
  my ($class, $attr_child) = @_;
  # Проверяем атрибуты потомка
  $attr_child = {} unless $attr_child;
  # Заполняем поля объекта
  my %attr = (
  	action_prefix	=> 'ARTICLE', # Префикс, который используется при регистрации действий
    list => [],				          # Список записей
  	## Параметры базы данных
  	db => {
  		table => 'article', # Название таблицы, с которой работает модуль
  	},
  	%{$attr_child}
  );
  # Вызываем конструктор базового класса и передаем ему атрибуты текущего
  $class->SUPER::new(\%attr);
}

=nd
Method: setTpl($name_tpl)
  Устанавливает шаблон для данного модуля. Принимает имя шаблона.
=cut
sub setTpl {
  my ($self, $tpl) = @_;
  # Выставляем шаблон, данные берутся из конфига
  $self->R->{template} = Tatooine::Base::T->{admin}{article}{$tpl};;
}

# Процедура проверки вводимых данных
sub validateData {
  my $self = shift;
  my $V = Tatooine::Validator->new($self->R);

  $V->validate(
  	{
  		title	=> 'TITLE',
  		sort	=> 'INTEGER'
  	}
  );
}

1;
```

Далее необходимо в папке public_html/admin/article/ создать скрипт:
```perl
#! /usr/bin/perl

use strict;
use warnings;
use utf8;

use lib '../../../lib';

use Tatooine::Router;
use Article;

# Создаем объект роутера
my $router = Tatooine::Router->new();

# Создаём объект модуля
my $article = Article->new({
  router => $router
});
# Регистрируем действия модуля (будут зарегистрированы действия редактирования, 
# удаления, валидации и вывода записей)
$article->registerActions;

# Для переопределения какого-либо действия используется следующая конструкция
# Запоминаем действие базового класса
my $ba_main = $router->{action}{$article->Prefix.'_MAIN'};
$router->registerAction($article->Prefix.'_MAIN' => { do => sub {
		my $S = shift;
		
		# Идентифицируем раздел
		$S->F->{active_section} = 'article';
		
		# Вызываем действие базового класса
		$ba_main->{do}->($S);
	}
});

# Для добавления нового действия используется следующая конструкция
$router->registerAction($article->Prefix.'_NEW_ACTION' => { do => sub {
    my $S = shift;
    
    ...
    
    $article->setTpl("NEW_ACTION_TPL");
    return "STOP";
  }
});

# Выбираем действие(я)
$router->selectActions ( sub {
  my $S = shift;
  my @act;
  
  # Поиск стандартных действий в зависимости от пришедших параметров CGI
  push @act, $article->selectActions;
  
  # Поиск новых действий
  push @act, $article->Prefix.'_NEW_ACTION' if $S->F->{new_action_param};
  
  return @act;
});

$router->listen;
```
