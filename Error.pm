package Tatooine::Error;

=nd
Package: Error
        Функции обработки ошибок. Ошибки классифицируются на системные и пользовательские.
=cut

use strict;
use warnings; 

use base qw(Exporter);
our @EXPORT = qw(systemError userError checkErrors getErrors regUserErrors clearErrors);

=nd
Стэк для хранения системных ошибок.
=cut
my @system_errors;

=nd
Стэк для хранения пользовательских ошибок.
=cut
my @user_errors;

=nd
Function: systemError($error)
	Фиксирует системные ошибки. Вывод ошибки в лог.

See Also:
	userError
=cut
sub systemError {
	my $error = shift;
	warn "SYSTEM ERROR: ".$error;
	push @system_errors, $error;
}

=nd
Function: userError($error)
	Фиксирует пользовательские ошибки.

See Also:
	systemError
=cut
# Ошибки пользователя
sub userError {
	my $error = shift;
	push @user_errors, $error;
}

=nd
Function: checkErrors()
		Проверка стэков на наличие ошибок. 

Parameters:
	SYSTEM - проверка системных ошибок(@system_errors)
	USER - проверка пользовательских ошибок(@user_errors)
=cut
# Проверка на наличие ошибок
sub checkErrors {
	my $type_error = shift;
	if($type_error eq 'SYSTEM') {
		for my $error (@system_errors) {
			return 1 if $error;
		}
	} elsif($type_error eq 'USER') {
		for my $error (@user_errors) {
			return 1 if $error;
		}
	} else {
		warn 'function check_error called without argument\n';
	}
}

=nd
Function: getErrors()
		Получить коды ошибок
=cut
sub getErrors {
	return @user_errors;
}

=nd
Function: regUserErrors()
		Регистрирует ошибки пользователя, при заполнения полей.
=cut
sub regUserErrors {
	my ($script, $name, $error_type) = @_;
	@user_errors = ();
	foreach my $key (keys %{$name}) {
		if (!$script->F->{$key} and $script->F->{$key} ne '0' or $script->F->{$key} eq ' ') {
			$script->F->{message}{class} = $error_type;
			push @{$script->F->{message}{msg}}, $name->{$key};
			$key = uc $key; #Переводим в верхний регистр, делается для шаблона
			userError("NO_$key");
		}
	}
}
=nd
Function: clearErrors()
		Очистка стека ошибок 

=cut
# Проверка на наличие ошибок
sub clearErrors {
(@system_errors, @user_errors) = ();
}

1;