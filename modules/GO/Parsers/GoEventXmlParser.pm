# $Id$
#
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Parsers::GoEventXmlParser;

=head1 NAME

  GO::Parsers::GoEventXmlParser     - Parses xml made from events

=head1 SYNOPSIS

  do not use this class directly; use GO::Parser

=cut

=head1 DESCRIPTION

this parser does a direct translation of XML to events, passed on to the handler

the XML used should be the attribute-less xml generated by the
GO::Handlers::XmlOutHandler class

=head1 AUTHOR

=cut

use Exporter;
use GO::Parsers::BaseParser;
@ISA = qw(GO::Parsers::BaseParser Exporter);

use Carp;
use FileHandle;
use strict qw(subs vars refs);
use XML::Parser;

sub parse_file {
    my ($self, $file) = @_;

    my $str = "";
    my $handlers =
      {
       Start=>
       sub {
           my ($e, $elt) = @_;
           $self->handler->start_event($elt);
           $str = "";
           return;
       },
       End=>
       sub {
           my ($e, $elt) = @_;
           $str =~ s/^\s*//;
           $str =~ s/\s*$//;
           $self->handler->evbody($str) if $str;
           $self->handler->end_event($elt);
           $str = "";
           return;
       },
       Char =>
       sub {
           my ($e, $char) = @_;
           $str .= $char;
           return;
       },
      };

    my $p = new XML::Parser(Handlers => $handlers);
    $p->parsefile($file);
}

1;