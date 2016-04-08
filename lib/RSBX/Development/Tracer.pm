#!/usr/bin/perl

#  Copyright (c) 2016, Raymond S Brand
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#
#   * Redistributions in source or binary form must carry prominent
#     notices of any modifications.
#
#   * Neither the name of Raymond S Brand nor the names of its other
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
#  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
#  COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
#  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
#  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
#  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
#  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.


use strict;
use warnings;
#no autovivification qw( fetch exists delete );
#no autovivification 'warn';


package RSBX::Development::Tracer v1.1.0.1;


use Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( );
our @EXPORT_OK = qw( TracerConfig TracerConfigPackage TracerDetail );
our @EXPORT = qw( TRACER TRACER_TEXT TRACER_ENTER TRACER_ENTER_TEXT TRACER_EXIT TRACER_EVAL_ENTER TRACER_EVAL_EXIT );


######
## Tracing Configuration
######

my @Config_Keys = qw( FH Indent Substitutions Detail );


######
## Tracing State
######

my %trace_conf;
my @trace_stack;
my @eval_stack;


######
## Private Subroutines
######

sub _STACK_PUSH
	{
	my ($pack) = @_;

	if (
			$pack ne $trace_stack[$#trace_stack]->[0]
			&& exists($trace_conf{$pack})
			)
		{
		push @trace_stack, [$pack, 0];
		}
	}


sub _STACK_POP
	{
	if (!$trace_stack[$#trace_stack]->[1] && @trace_stack > 1)
		{
		pop @trace_stack;
		}
	}


sub _DEPTH_INCREASE
	{
	$trace_stack[$#trace_stack]->[1]++;

	return $trace_stack[$#trace_stack]->[1];
	}


sub _DEPTH_DECREASE
	{
	$trace_stack[$#trace_stack]->[1]--;

	return $trace_stack[$#trace_stack]->[1];
	}


sub _Substitute
	{
	my ($string) = @_;

	if (exists($trace_conf{$trace_stack[$#trace_stack]->[0]}->{'Substitutions'})
			&& ref($trace_conf{$trace_stack[$#trace_stack]->[0]}->{'Substitutions'}) eq 'ARRAY')
		{
		my $subs_ref = $trace_conf{$trace_stack[$#trace_stack]->[0]}->{'Substitutions'};

		$string = '' if !defined($string);

		foreach my $sub (@{$subs_ref})
			{
			if (@{$sub} > 2 && $sub->[2])
				{
				$string =~ s/$sub->[0]/$sub->[1]/g;
				}
			else
				{
				$string =~ s/$sub->[0]/$sub->[1]/;
				}
			}
		}

	return $string;
	}


sub _Output
	{
	if (defined($trace_conf{$trace_stack[$#trace_stack]->[0]}->{'FH'})
			&& defined(fileno($trace_conf{$trace_stack[$#trace_stack]->[0]}->{'FH'})))
		{
		my $buffer;
		my @time = localtime;

		$buffer .= '[' . sprintf('%04d-%02d-%02d %02d:%02d:%02d', 1900+$time[5], 1+$time[4], $time[3], $time[2], $time[1], $time[0]) . ']';
		$buffer .= ' ';
		$buffer .= '[' . $$ . ']';
		$buffer .= ' ';

		foreach my $pack (@trace_stack)
			{
			if (defined($trace_conf{$pack->[0]}->{'FH'})
					&& defined(fileno($trace_conf{$pack->[0]}->{'FH'}))
					&& fileno($trace_conf{$trace_stack[$#trace_stack]->[0]}->{'FH'}) == fileno($trace_conf{$pack->[0]}->{'FH'})
					)
				{
				$buffer .= $trace_conf{$pack->[0]}->{'Indent'} x $pack->[1];
				}
			}

		$buffer .= join('', @_);

		print {$trace_conf{$trace_stack[$#trace_stack]->[0]}->{'FH'}} $buffer, "\n";
		}
	}


######
## Public Subroutines
######

sub TracerConfigPackage
	{
	my ($pack, %options) = @_;

	if (!exists($trace_conf{$pack}))
		{
		$trace_conf{$pack} =
				{
				'FH'		=> undef,
				'Indent'	=> '.',
				'Substitutions'	=> [],
				'Detail'	=> 0,
				};

		push @trace_stack, [$pack, 0];
		}

	foreach my $key (@Config_Keys)
		{
		if (exists($options{$key}))
			{
			$trace_conf{$pack}->{$key} = $options{$key};
			delete($options{$key});
			}
		}

	return \%options;
	}


sub TracerConfig
	{
	my (%options) = @_;

	return TracerConfigPackage((caller(0))[0], %options);
	}


sub TracerDetail
	{
	my $pack = shift || (caller(0))[0];

	return $trace_conf{exists($trace_conf{$pack}) ? $pack : $trace_stack[$#trace_stack]->[0]}->{'Detail'};
	}


sub TRACER
	{
	_STACK_PUSH((caller(0))[0]);

	_Output(_Substitute((caller(1))[3] || '<UNDEF>'), @_);

	_STACK_POP();
	}


sub TRACER_TEXT
	{
	_STACK_PUSH((caller(0))[0]);

	_Output(@_);

	_STACK_POP();
	}


sub TRACER_ENTER
	{
	_STACK_PUSH((caller(0))[0]);

	_Output(_Substitute((caller(1))[3] || '<UNDEF>'), @_);

	_DEPTH_INCREASE();

	_Output('{');
	}


sub TRACER_ENTER_TEXT
	{
	_STACK_PUSH((caller(0))[0]);

	_Output(@_);

	_DEPTH_INCREASE();

	_Output('{');
	}


sub TRACER_EXIT
	{
	_Output('} ', @_);

	_STACK_POP() if !_DEPTH_DECREASE();
	}


sub TRACER_EVAL_ENTER
	{
	push @eval_stack, [$#trace_stack, $trace_stack[$#trace_stack]->[1]];
	}


sub TRACER_EVAL_EXIT
	{
	my ($stack_depth, $trace_depth) = @{pop @eval_stack};

	$#trace_stack = $stack_depth;
	$trace_stack[$#trace_stack]->[1] = $trace_depth;
	}


######
## One Time Initializations
######

TracerConfigPackage((caller(1))[0]);


1;


__END__


=pod

=head1 NAME

RSBX::Development::Tracer - Package call tracing instrumentation support.

=head1 SYNOPSIS

 use RSBX::Development::Tracer qw( :DEFAULT TracerConfig TracerDetail );
 ...
 TracerConfig('FH' => *STDERR);
 ...
 sub MySub1 {
     TRACER_ENTER();
     ...
     TRACER_TEXT('Something important:', $value) if TracerDetail() > 3;
     ...
     TRACER_EXIT();
     }
 ...
 sub MySub2 {
     TRACER("('", join("', '", @_), "')");
     ...
     }
 ...

=head1 DESCRIPTION

C<RSBX::Development::Tracer> is used to instrument packages to output call
trace information, with representative brackets and indenting, to make
development and/or debugging easier. The output produced is similar to the
following (with out the line numbers that were added for expository purposes):

 01  [1970-03-14 15:92:65] [358] main::MySubA
 02  [1970-03-14 15:92:65] [358] .  {
 03  [1970-03-14 15:92:65] [358] .  main::MySubB
 04  [1970-03-14 15:92:65] [358] .  .  {
 05  [1970-03-14 15:92:65] [358] .  .  Package1::Sub1
 06  [1970-03-14 15:92:65] [358] .  .  .  {
 07  [1970-03-14 15:92:65] [358] .  .  .  Package2::Sub2
 08  [1970-03-14 15:92:65] [358] .  .  .  .  {
 09  [1970-03-14 15:92:65] [358] .  .  .  .  }
 10  [1970-03-14 15:92:65] [358] .  .  .  }
 11  [1970-03-14 15:92:65] [358] .  .  main::MySubC(1)
 12  [1970-03-14 15:92:65] [358] .  .  .  {
 13  [1970-03-14 15:92:65] [358] .  .  .  main::MySubD = something
 14  [1970-03-14 15:92:65] [358] .  .  .  }
 15  [1970-03-14 15:92:65] [358] .  .  } = undef
 16  [1970-03-14 15:92:65] [358] .  Important: 15
 17  [1970-03-14 15:92:65] [358] .  }

This example demonstrates the use of:

=over 4

=item * Custom indent string, C<'.  '>, (dot, space, space) 

=item * C<TRACER_ENTER();>

Lines 01-08

=item * C<TRACER_ENTER('(', $_[0], ')');>

Lines 11-12

=item * C<TRACER_EXIT();>

Lines 09-10, 14, 17

=item * C<TRACER_EXIT(' = undef');>

Line 15

=item * C<TRACER(' = ', "something");>

Line 13

=item * C<TRACER_TEXT('Important: ', 15);>

Line 16

=back

=head1 CALLABLES

=head2 CONFIGURATION

=over 4

=item TracerConfig ( [ OPTIONS ] )

Sets tracing configuration options for the calling package.

=over 4

=item OPTIONS

Name/value pairs.

=over 4

=over 4

=item C<'FH'> =E<gt> I<filehandle>

Perl file descriptor where tracing output should be written to.  Or C<undef>
to not write any tracing lines for the calling package.

Default: C<undef>

=item C<'Indent'> =E<gt> I<string>

String to use for indenting the number of encountered L</TRACER_ENTER> or
L</TRACER_ENTER_TEXT> calls without a corresponding L</TRACER_EXIT> call.

Default: C<'.'>

=item C<'Detail'> =E<gt> I<value>

The value to return from a L</TracerDetail> call for the calling package.
It is suggested that the value be numeric but no validation is performed.

Default: C<0>

=item C<'Substitutions'> =E<gt> I<ARRAY_ref>

Reference to an array of I<search and replace> specification that are applied,
in order, to the name of the calling subroutine of L</TRACER> and
L</TRACER_ENTER>.

Each I<search and replace> specification is a reference to an array of 2
elements followed by an optional I<all> truth value.
The first element is the regular expression to search for; and the second
element is the replacement.
If the optional I<all> truth value evaluates to true, then all occurances of
the search regular expression are replaced.

Default: C<[]>

=back

=back

=item RETURNS

=over 4

=over 4

Reference to a hash containing any unknown options.

=back

=back

=back

=item TracerConfigPackage ( I<package> [, OPTIONS ] )

Sets tracing configuration options for the specified package.

=over 4

=item PARAMETERS

=over 4

=over 4

=item I<package>

The full name of the package that the suppied configuration options are to
apply to.

=back

=back

=item OPTIONS

Name/value pairs.

=over 4

=over 4

=item C<'FH'> =E<gt> I<filehandle>

Perl file descriptor where tracing output should be written to.  Or C<undef>
to not write any tracing lines for the calling package.

Default: C<undef>

=item C<'Indent'> =E<gt> I<string>

String to use for indenting the number of encountered L</TRACER_ENTER> or
L</TRACER_ENTER_TEXT> calls without a corresponding L</TRACER_EXIT> call.

Default: C<'.'>

=item C<'Detail'> =E<gt> I<value>

The value to return from a L</TracerDetail> call for the calling package.
It is suggested that the value be numeric but no validation is performed.

Default: C<0>

=item C<'Substitutions'> =E<gt> I<ARRAY_ref>

Reference to an array of I<search and replace> specification that are applied,
in order, to the name of the calling subroutine of L</TRACER> and
L</TRACER_ENTER>.

Each I<search and replace> specification is a reference to an array of 2
elements followed by an optional I<all> truth value.
The first element is the regular expression to search for; and the second
element is the replacement.
If the optional I<all> truth value evaluates to true, then all occurances of
the search regular expression are replaced.

default: C<[]>

=back

=back

=item RETURNS

=over 4

=over 4

Reference to a hash containing any unknown options.

=back

=back

=back

=back

=head2 DEPTH RECORDING

=over 4

=item TRACER_ENTER ( I<LIST> )

Outputs 2 lines to the configured tracing output file descriptor of the
calling package or that of the last package on the tracing depth stack
with a configured tracing output file descriptor.

The lines will be similar to:

 [1970-03-14 15:92:65] [358] <INDENT*>__PACKAGE__::MySub<LIST>
 [1970-03-14 15:92:65] [358] <INDENT*><INDENT>{

But with:

=over 4

=item * The current local date and time (instead of the digits of pi)

=item * The process id ($$)

=item * The correct amount of identing using the configured indent strings

=item * The package name of the caller

=item * The subroutine name of the caller

=item * The I<LIST> provided as an argument

=back

And increases the indenting level by 1.

=over 4

=item PARAMETERS

=over 4

=over 4

=item I<LIST>

A list of strings (or expressions that evaluate to strings) to append to the
trace output line.

=back

=back

=item RETURNS

=over 4

=over 4

=item Nothing.

=back

=back

=back

=item TRACER_ENTER_TEXT ( I<LIST> )

Outputs 2 lines to the configured tracing output file descriptor of the
calling package or that of the last package on the tracing depth stack
with a configured tracing output file descriptor.

The lines will be similar to:

 [1970-03-14 15:92:65] [358] <INDENT*><LIST>
 [1970-03-14 15:92:65] [358] <INDENT*><INDENT>{

But with: 

=over 4 

=item * The current local date and time (instead of the digits of pi)

=item * The process id ($$)

=item * The correct amount of identing using the configured indent strings

=item * The I<LIST> provided as an argument

=back

And increases the indenting level by 1.

=over 4

=item PARAMETERS

=over 4

=over 4

=item I<LIST>

A list of strings (or expressions that evaluate to strings) to append to the
trace output line.

=back

=back

=item RETURNS

=over 4

=over 4

=item Nothing.

=back

=back

=back

=item TRACER_EXIT ( I<LIST> )

Outputs 1 line to the configured tracing output file descriptor of the
calling package or that of the last package on the tracing depth stack
with a configured tracing output file descriptor.

The line will be similar to:

 [1970-03-14 15:92:65] [358] <INDENT*>} <LIST>

But with:

=over 4

=item * The current local date and time (instead of the digits of pi)

=item * The process id ($$)

=item * The correct amount of identing using the configured indent strings

=item * The I<LIST> provided as an argument

=back

And decreases the indenting level by 1.

=over 4

=item PARAMETERS

=over 4

=over 4

=item I<LIST>

A list of strings (or expressions that evaluate to strings) to append to the
trace output line.

=back

=back

=item RETURNS

=over 4

=over 4

=item Nothing.

=back

=back

=back

=back

=head2 TEXT

=over 4

=item TRACER ( I<LIST> )

Outputs 1 line to the configured tracing output file descriptor of the
calling package or that of the last package on the tracing depth stack
with a configured tracing output file descriptor.

The line will be similar to:

 [1970-03-14 15:92:65] [358] <INDENT*>__PACKAGE__::MySub<LIST>

But with:

=over 4

=item * The current local date and time (instead of the digits of pi)

=item * The process id ($$)

=item * The correct amount of identing using the configured indent strings

=item * The package name of the caller

=item * The subroutine name of the caller

=item * The I<LIST> provided as an argument

=back

=over 4

=item PARAMETERS

=over 4

=over 4

=item I<LIST>

A list of strings (or expressions that evaluate to strings) to append to the
trace output line.

=back

=back

=item RETURNS

=over 4

=over 4

=item Nothing.

=back

=back

=back

=item TRACER_TEXT ( I<LIST> )

Outputs 1 line to the configured tracing output file descriptor of the
calling package or that of the last package on the tracing depth stack
with a configured tracing output file descriptor.

The line will be similar to:

 [1970-03-14 15:92:65] [358] <INDENT*><LIST>

But with:

=over 4

=item * The current local date and time (instead of the digits of pi)

=item * The process id ($$)

=item * The correct amount of identing using the configured indent strings

=item * The I<LIST> provided as an argument

=back

=over 4

=item PARAMETERS

=over 4

=over 4

=item I<LIST>

A list of strings (or expressions that evaluate to strings) to append to the
trace output line.

=back

=back

=item RETURNS

=over 4

=over 4

=item Nothing.

=back

=back

=back

=back

=head2 EVAL RECOVERY

=over 4

=item TRACER_EVAL_ENTER ( )

Use L</TRACER_EVAL_ENTER> and L</TRACER_EVAL_EXIT> to bracket C<eval> calls to
keep the tracing configuration and depth tracking consistent in the event
that eval traps an exception. Produces no output.

=over 4

=item RETURNS

=over 4

=over 4

=item Nothing.

=back

=back

=back

=item TRACER_EVAL_EXIT ( )

Use L</TRACER_EVAL_ENTER> and L</TRACER_EVAL_EXIT> to bracket C<eval> calls to 
keep the tracing configuration and depth tracking consistent in the event 
that C<eval> traps an exception. Produces no output.

=over 4

=item RETURNS

=over 4

=over 4

=item Nothing.

=back

=back

=back

=back

=head2 OTHER

=over 4

=item TracerDetail ( [ I<package> ] )

Retrieve the C<'Detail'> configuration option for the calling package or that
of the last package on the tracing configuration and depth tracking stack that
was configured.

=over 4

=item OPTIONS

=over 4

=over 4

=item I<package>

Use I<package> instead of the calling package.

=back

=back

=item RETURNS

=over 4

=over 4

=item I<value>

The value of the C<'Detail'> configuration option for the calling package or
that of the last package on the tracing configuration and depth tracking stack
that was configured.

=back

=back

=back

=back

=head1 ADVANDED USAGE

=over 4

=item *
Not every instrumented package needs to be configured. When a I<TRACER> call
is made by an non-configured package, the configuration of the last configured
package in the tracing configuration and depth tracking stack continues to be
used.

=item *
Use of the C<'Substitutions'> configuration option can greatly increase the
readability of the tracing output.

=item *
All indenting from configurations with different or undefined output file
descriptors is omitted. This is useful if you have deep call stacks but you
don't care about some of the packages in the middle of the stack.

=back

=head1 DIAGNOSTICS

None.

=head1 BUGS AND LIMITATIONS

=over 4

=item * Almost no argument validation is performed. Code wisely.

=back

Please report problems to Raymond S Brand E<lt>rsbx@acm.orgE<gt>.

Problem reports without included demonstration code and/or tests will be ignored.

Patches are welcome.

=head1 AUTHOR

Raymond S Brand E<lt>rsbx@acm.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2016 Raymond S Brand. All rights reserved.

=head1 LICENSE

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

=over 4

=item *

Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

=item *

Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in
the documentation and/or other materials provided with the
distribution.

=item *

Redistributions in source or binary form must carry prominent
notices of any modifications.

=item *

Neither the name of Raymond S Brand nor the names of its other
contributors may be used to endorse or promote products derived
from this software without specific prior written permission.

=back

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

=cut

