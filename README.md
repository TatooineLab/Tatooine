# Tatooine

Tatooine - Perl framework for web applications.

## Getting Started
The base script in the public direcory:

```perl
#! /usr/bin/perl

use strict;
use warnings;
use utf8;

use lib '../lib';

use Tatooine::Router;

# Object for management of actions.
my $router = Tatooine::Router->new();

# Register action
$router->registerAction(MAIN => { do => sub {
  	my $S = shift; # link of object $router

    # Flow for ouput data
    $S->F->{output_data} = 'test data';

    # Set html template
    $S->setPubTpl('MAIN');
    # It means that after this action, we can not execute other actions
    return 'STOP';
	}
});

# Select action(s) depending on CGI paramaeter(s)
$router->selectActions ( sub {
  	my $S = shift;
  	my @act;
  
    # Default action
    push @act, 'MAIN';
  
  	return @act;
});
# Run
$router->listen;
```

