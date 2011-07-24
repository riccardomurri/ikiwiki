#!/usr/bin/perl
#
# An adapter to use Template::Toolkit instead of HTML::Template.
#
# Author: riccardo.murri@gmail.com
# License: GPL license
#
# Template::Toolkit support for IkiWiki

use warnings;
use strict;
use IkiWiki 3.00;

package IkiWiki::TT;

use Template;

our $VERSION = '0.1';

sub new {
    my $class = shift;
    my $opts = { @_ };

    my $filename = $opts->{filename}; 
 
    my $path = $opts->{path} || '.';
    # emulate HTML::Template search behavior, see:
    # http://search.cpan.org/~samtregar/HTML-Template-2.6/Template.pm#TMPL_INCLUDE
    if (defined($ENV{HTML_TEMPLATE_ROOT})) {
        $path ="$ENV{HTML_TEMPLATE_ROOT}:$path:$ENV{HTML_TEMPLATE_ROOT}/$path:";
    }

    # unsafe TT operations
    my $trusted = not $opts->{no_includes};

    # cleanup HTML::Template keys that may conflict with TT processing
    delete $opts->{blind_cache};
    delete $opts->{filter};
    delete $opts->{no_includes};
    delete $opts->{path};

    my $self = {
        TT => Template->new({
            SERVICE => IkiWiki::TT::Service->new(),
            EVAL_PERL => $trusted,
            ABSOLUTE  => $trusted,
            RELATIVE  => $trusted,
            INCLUDE_PATH => $path,
        }),
        params => $opts,
        filename => $filename,
    };
    return bless($self, $class);
};


sub param {
    my $self = shift;
    my %params = @_;

    $self->{params}->{$_} = $params{$_}
        foreach (keys %params);
};


sub output {
    my $self = shift;

    unless ($self->{_output}) {
        my $result = '';
        my $success = $self->{TT}->process($self->{filename}, $self->{params}, \$result);
        $self->{_output} = $result;
    }
    return $self->{_output};
};


sub query {
    my $self = shift;
    my $opts = { @_ };

    # XXX: HTML::Template returns 'LOOP' if the queried param is used in a
    # loop, and 'VAR' otherwise.  I know of no way of getting this
    # behavior with Template::Toolkit, but apparently all uses of `query`
    # in IkiWiki are simple presence tests.
    die ("IkiWiki::TT cannot emulate HTML::Template->query with loop argument") 
        if defined $opts->{loop};

    my $name = $opts->{name};
    if ('ARRAY' eq ref($name)) {
        my @result = ();
        unshift (@result, (defined($self->{params}->{$_})? 'VAR' : undef))
            foreach @$name;
        return @result;
    }
    else {
        # XXX: assume $name is a plain string
        return defined($self->{params}->{$name})? 'VAR' : undef;
    }
}


package IkiWiki::TT::Service;

use Template::Service;
use Encode;

our $VERSION = '0.1';

sub new {
    my $class = shift;
    my $self = {
        SERVICE => Template::Service->new(@_),
    };
    return bless($self, $class);
}


sub context {
    my $self = shift;
    return $self->{SERVICE}->context();
};


sub error {
    my $self = shift;
    return $self->{SERVICE}->error();
};

sub process {
    my $self = shift;
    my $input = shift;
    my $replace_ref = shift;
    
    # read input text, decode it (using Encode::decode_utf8), and
    # forward to the real service
    my $text;
    my $what = ref($input);
    if ('SCALAR' eq $what) {
        # actual text
        $text = Encode::decode_utf8(${$input});
    }
    elsif ('GLOB' eq $what) {
        # ref to file handle
        local $/ = undef;
        $text = <${input}>;
        $text = Encode::decode_utf8($text);
    }
    elsif ('' eq $what) {
        # ref to file name
        local $/ = undef;
        open (FILE, '<', $input)
            or die "Cannot open input file $what: $!";
        $text = <FILE>;
        $text = Encode::decode_utf8($text);
        close FILE;
    }
    else {
        die ("Ikiwiki::TT::Service->process"
             ." got argument $what ("
             .(ref($what))
             .") which it cannot handle.");
    };
    return $self->{SERVICE}->process(\$text, $replace_ref);
}


1;
__END__
