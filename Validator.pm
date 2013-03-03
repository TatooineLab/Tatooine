package Tatooine::Validator;
$VERSION = 12.08.16.1;

=nd
Package: Validator
	Служит для валидации данных
=cut

use strict;
use warnings;

use utf8;

use Tatooine::DB;

=nd
Method: new
	Конструктор. Создает объект модуля.
=cut
sub new {
	my ($class, $router) = @_;
	my $self = bless {
		router => $router
	}, $class;
}

=nd
Function: getRule
	Процедура получения RegExp-выражения для определённой маски
=cut
sub getRule {
	my ($self, $mask) = @_;
	my $rule;

	## Общее
	$rule = qr/^\d{2}\.(\d{2})\.\d{2,4}$/ 	if $mask eq 'DATE';
	$rule = qr/^\d+:\d+$/	 		if $mask eq 'HH:MM';
	$rule = qr/^([\w|\s|,]+)$/		if $mask eq 'COUNTRY';
	$rule = qr/^(-?[\d]+)$/			if $mask eq 'INTEGER';
	$rule = qr/^([\d]+[\.]?[\d]*)$/		if $mask eq 'FLOAT';
	$rule = qr/^[^-]/			if $mask eq 'POSITIVE';

	## Пользователи
	$rule = qr/^([\d]|[A-z]|\/)+$/		if $mask eq 'LOGIN';
	$rule = qr/^([0-9a-z]*([-|_]?[0-9a-z]+)*)(([-|_]?)\.([-|_]?)[0-9a-z]*([-|_]?[0-9a-z]+)+)*([-|_]?)@([0-9a-z]+([-]?[0-9a-z]+)*)(([-]?)\.([-]?)[0-9a-z]*([-]?[0-9a-z]+)+)*\.[a-z]{2,4}$/
						if $mask eq 'EMAIL';
	$rule = qr/^([A-Za-zА-Яа-я])+$/ 	if $mask eq 'NAME';

	return $rule;
}

=nd
Function: getLengthMaxRule
	Процедура получения максимальной длины поля для определённой маски
=cut
sub getLengthMaxRule {
	my ($self, $mask) = @_;
	my $rule;

	$rule = 30	if $mask eq 'LOGIN';
	$rule = 50	if $mask eq 'EMAIL';
	$rule = 50	if $mask eq 'NAME';

	return $rule;
}

=nd
Function: getLengthMinRule
	Процедура получения минимальной длины поля для определённой маски
=cut
sub getLengthMinRule {
	my ($self, $mask) = @_;
	my $rule;

	$rule = 3	if $mask eq 'LOGIN';
	$rule = 5	if $mask eq 'PASSWORD';

	return $rule;
}

=nd
Function: existRecord
	Процедура проверки существования записи по определённому полю

Parameters:
	$key 		- название поля, по которому надо искать
	$table 		- таблица, в которой надо искать
	$where		- если условий выборки больше
=cut
sub existRecord {
	my ($self, $key, $table, $where) = @_;
	my $db = Tatooine::DB->new($self->R);

	$where = { $key => $self->R->F->{$key} } unless $where;

	# Если в потоке есть id, то запись редактируется
	if ($self->R->F->{id}) {
		$where->{id}{value} = $self->R->F->{id};
		$where->{id}{sign} = '!=';
	}

	# Ищем запись в базе
	my $exist = $db->getRecord(
		{
			table => $table,
			fields => $key,
			where => $where
		}
	);

	# Формируем сообщение об ошибке
	push @{$self->R->F->{error}{$key}}, 'exist' if $exist;

	return $exist;
}

=nd
Function: validate(ref %mask)
	Процедура проверки поля

Parameters:
	ref %mask    	- хеш (поле => маска), по которому будут проверяться поля
=cut
sub validate {
	my ($self, $mask) = @_;
	foreach my $key (keys %{$mask}){
		## Получаем правило для регулярного выражения
		# Если для элемента указано несколько правил, то перебираем их
		if (ref $mask->{$key} eq 'ARRAY' and $self->R->F->{$key}){
			foreach my $r (@{$mask->{$key}}) {
				my $rule = $self->getRule($r);
				# Декодируем поле для проверки русских символов
				utf8::decode($self->R->F->{$key});
				if ($rule and $self->R->F->{$key} !~ $rule) {
					# Записываем тип ошибки
					if ($r eq 'POSITIVE') {
						push @{$self->R->F->{error}{$key}}, 'negative';
					} else {
						push @{$self->R->F->{error}{$key}}, 'incorrect';
					}
				}
			}
		} elsif ($self->R->F->{$key}){
			my $rule = $self->getRule($mask->{$key});
			# Декодируем поле для проверки русских символов
			utf8::decode($self->R->F->{$key});
			if ($rule and $self->R->F->{$key} !~ $rule) {
				# Записываем тип ошибки
				if ($mask->{$key} eq 'POSITIVE') {
					push @{$self->R->F->{error}{$key}}, 'negative';
				} else {
					push @{$self->R->F->{error}{$key}}, 'incorrect';
				}
			}
		}

		# Получаем максимальную длину поля
		if ($self->R->F->{$key}){
			my $length_max_rule = $self->getLengthMaxRule($mask->{$key});
			if ($length_max_rule and length($self->R->F->{$key}) > $length_max_rule) {
				# Записываем тип ошибки
				push @{$self->R->F->{error}{$key}}, 'incorrect_length_max';
			}
		}

		# Получаем минимальную длину поля
		if ($self->R->F->{$key}){
			my $length_min_rule = $self->getLengthMinRule($mask->{$key});
			if ($length_min_rule and length($self->R->F->{$key}) < $length_min_rule) {
				# Записываем тип ошибки
				push @{$self->R->F->{error}{$key}}, 'incorrect_length_min';
			}
		}
	}
}

=nd
Method: R
	Метод доступа к объекту Script
=cut
sub R { shift->{router} }

1;