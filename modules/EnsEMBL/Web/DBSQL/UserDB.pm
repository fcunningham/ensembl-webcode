package EnsEMBL::Web::DBSQL::UserDB;
# File Apache/EnsEMBL/UserDB.pm

#  _userdatatype_ID and its uses
#   1  WebUserConfig/contigviewbottom
#   2  WebUserConfig/contigviewtop
#   3  WebUserConfig/geneview
#   4  WebUserConfig/protview
#   5  WebUserConfig/seqentryview
#   6  WebUserConfig/chromosome
#   7  WebUserConfig/transview
#   8  WebUserConfig/vc_dumper
#   9  External DAS sources

use DBI;
use EnsEMBL::Web::SpeciesDefs;
use Digest::MD5;
use strict;
use CGI::Cookie;

sub new {
  my $caller = shift;
  my $r = shift;
  my $class = ref($caller) || $caller;
  my $self = { '_request' => $r };
  if(defined( EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_NAME ) and EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_NAME ne '') {
    eval {
      $self->{'_handle'} =
         DBI->connect(
 	  	"dbi:mysql:@{[EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_NAME]}:@{[EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_HOST]}:@{[EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_PORT]}",
		EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_USER,
		EnsEMBL::Web::SpeciesDefs->ENSEMBL_USERDB_PASS,
	        {RaiseError=>1,PrintError=>0}
         );
    };
    unless($self->{'_handle'}) {
       warn( "Unable to connect to authentication database: $DBI::errstr" );
       $self->{'_handle'} = undef;
    }
  } else {
    warn( "NO DB USER DATABASE DEFINED" );
    $self->{'_handle'} = undef;
  }
  bless $self, $class;
  return $self;
}

sub create_session {
  my $self            = shift; 
  my $firstsession_ID = shift;
  my $uri             = shift;
  return unless( $self->{'_handle'} );
  $self->{'_handle'}->do("lock tables SESSION write");
  $self->{'_handle'}->do(
            "insert into SESSION
                set firstsession_ID =?, starttime = now(), endtime = now(),
                    pages = 0, startpage = ?", {},
            $firstsession_ID, $uri
        );
  my $session_ID = $self->{'_handle'}->selectrow_array("select last_insert_id()");
  $self->{'_handle'}->do("unlock tables");
  return $session_ID;
}

sub update_session {
  my $self            = shift;
  my $session_ID      = shift;
  my $uri	 = shift;
  return unless( $self->{'_handle'} );
  $self->{'_handle'}->do(
    "update SESSION
        set pages = pages + 1, endtime = now(), endpage = ?
      where ID = ?", {},
    $uri, $session_ID
  );
} 

sub clearCookie {
  my $self = shift;
  my $r    = shift || $self->{'_request'};
  my $cookie = CGI::Cookie->new(
    -name    => EnsEMBL::Web::SpeciesDefs->ENSEMBL_FIRSTSESSION_COOKIE,
    -value   => EnsEMBL::Web::DBSQL::UserDB::encryptID(-1),
    -domain  => EnsEMBL::Web::SpeciesDefs->ENSEMBL_COOKIEHOST,
    -path    => "/",
    -expires => "Monday, 31-Dec-1970 23:59:59 GMT"
  );
  if( $r ) {
    $r->headers_out->add(     'Set-cookie' => $cookie );
    $r->err_headers_out->add( 'Set-cookie' => $cookie );
    $r->subprocess_env->{'ENSEMBL_FIRSTSESSION'} = 0;
  }
}

sub setConfigByName {
  my( $self, $r, $session_ID, $key, $value ) = @_;
  return unless $self->{'_handle'};
  unless($session_ID) {
    $session_ID = $self->create_session( 0, $r ? $r->uri : '' );
    my $cookie = CGI::Cookie->new(
      -name    => EnsEMBL::Web::SpeciesDefs->ENSEMBL_FIRSTSESSION_COOKIE,
      -value   => EnsEMBL::Web::DBSQL::UserDB::encryptID($session_ID),
      -domain  => EnsEMBL::Web::SpeciesDefs->ENSEMBL_COOKIEHOST,
      -path      => "/",
      -expires => "Monday, 31-Dec-2037 23:59:59 GMT"
    );
    if( $r ) {
      $r->headers_out->add( 'Set-cookie' => $cookie );
      $r->err_headers_out->add( 'Set-cookie' => $cookie );
      $r->subprocess_env->{'ENSEMBL_FIRSTSESSION'} = $session_ID;
    }
    $ENV{'ENSEMBL_FIRSTSESSION'} = $session_ID;
  }
  my( $key_ID ) = $self->{'_handle'}->selectrow_array( "select ID from USERDATATYPE where name = ?", {},  $key );
## Create a USERDATATYPE value if one doesn't exist!! ##
  unless( $key_ID ) {
    $self->{'_handle'}->do( "insert ignore into USERDATATYPE set name = ?", {}, $key );
    ( $key_ID ) = $self->{'_handle'}->selectrow_array( "select ID from USERDATATYPE where name = ?", {}, $key );
  }
  $self->{'_handle'}->do(
    "insert ignore into USERDATA
        set session_ID = ?, userdatatype_ID = ?",{},
    $session_ID, $key_ID
  );
  $self->{'_handle'}->do(
    "update USERDATA
        set value= ?, updated = now()
      where session_ID = ? and userdatatype_ID = ?",{},
    $value, $session_ID, $key_ID
  );
  return $session_ID;
}

sub clearConfigByName {
  my( $self, $session_ID, $key ) = @_;
  return unless $self->{'_handle'};
  return unless $session_ID;
  my( $key_ID ) = $self->{'_handle'}->selectrow_array( "select ID from USERDATATYPE where name = ?", {}, $key );
  return unless $key_ID;
  $self->{'_handle'}->do( "delete from USERDATA where session_ID = ? and userdatatype_ID = ?", {}, $session_ID, $key_ID );
}

sub getConfigByName {
  my( $self, $session_ID, $key ) = @_;
  return unless $self->{'_handle'};
  return unless $session_ID;
  my( $key_ID ) = $self->{'_handle'}->selectrow_array( "select ID from USERDATATYPE where name = ?", {}, $key );
  return unless $key_ID;
  my( $value ) = $self->{'_handle'}->selectrow_array( "select value from USERDATA where session_ID = ? and userdatatype_ID = ?", {}, $session_ID, $key_ID );
  return $value;
}

sub setConfig {
  my $self            = shift;
  my $r               = shift;
  my $session_ID      = shift;
  my $userdatatype_ID = shift || 1;
  my $value           = shift;
  return unless( $self->{'_handle'} );
  unless($session_ID) {
    $session_ID = $self->create_session( 0, $r ? $r->uri : '' );
    my $cookie = CGI::Cookie->new(
      -name    => EnsEMBL::Web::SpeciesDefs->ENSEMBL_FIRSTSESSION_COOKIE,
      -value   => EnsEMBL::Web::DBSQL::UserDB::encryptID($session_ID),
      -domain  => EnsEMBL::Web::SpeciesDefs->ENSEMBL_COOKIEHOST,
      -path 	 => "/",
      -expires => "Monday, 31-Dec-2037 23:59:59 GMT"
    );
    if( $r ) {
      $r->headers_out->add(	'Set-cookie' => $cookie );
      $r->err_headers_out->add( 'Set-cookie' => $cookie );
      $r->subprocess_env->{'ENSEMBL_FIRSTSESSION'} = $session_ID;
    }
    $ENV{'ENSEMBL_FIRSTSESSION'} = $session_ID;
  }
  $self->{'_handle'}->do(
   "insert ignore into USERDATA
       set session_ID = ?, userdatatype_ID = ?",{},
   $session_ID, $userdatatype_ID
  );
  $self->{'_handle'}->do(
    "update USERDATA
        set value= ?, updated = now()
      where session_ID = ? and userdatatype_ID = ?",{},
    $value, $session_ID, $userdatatype_ID
  );
  return $session_ID;
}

sub getConfig {
  my $self            = shift;
  my $session_ID      = shift;
  my $userdatatype_ID = shift || 1;  
  return unless( $self->{'_handle'} && $session_ID > 0 );
  my $value = $self->{'_handle'}->selectrow_array(
    "select value
       from USERDATA
      where session_ID = ? and userdatatype_ID = ?", {},
    $session_ID, $userdatatype_ID
  );
  return $value;
}

sub resetConfig {
  my $self            = shift;
  my $session_ID      = shift;
  my $userdatatype_ID = shift || 1;  
  return unless( $self->{'_handle'} && $session_ID > 0 );
  $self->{'_handle'}->do(
    "delete from USERDATA
      where session_ID = ? and userdatatype_ID = ?", {},
    $session_ID, $userdatatype_ID
  );
}

sub print_query {
  my $self = shift;
  my $q = shift;
  shift;
  foreach(@_) {
    $q=~s/\?/'$_'/;
  }
  $self->{'_request'}->log_reason("Query:\n-- $q") if($self->{'_request'});
}

sub encryptID {
    my $ID = shift;
    my $rand1 = 0x8000000 + 0x7ffffff * rand();
    my $rand2 = $rand1 ^ ($ID + EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_0);
    my $encrypted = crypt(crypt(crypt(sprintf("%x%x",$rand1,$rand2),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_1),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_2),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_3);
    my $MD5d = Digest::MD5->new->add($encrypted)->hexdigest();
    return sprintf("%s%x%x%s", substr($MD5d,0,16), $rand1, $rand2, substr($MD5d,16,16));

}

sub decryptID {
    my $encrypted = shift;
    my $rand1  = substr($encrypted,16,7);
    my $rand2  = substr($encrypted,23,7);
    my $ID = ( hex( $rand1 ) ^ hex( $rand2 ) ) - EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_0;
    my $XXXX = crypt(crypt(crypt($rand1.$rand2,EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_1),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_2),EnsEMBL::Web::SpeciesDefs->ENSEMBL_ENCRYPT_3);
    my $MD5d = Digest::MD5->new->add($XXXX)->hexdigest();
    $ID = substr($MD5d,0,16).$rand1.$rand2.substr($MD5d,16,16) eq $encrypted ? $ID : 0;
}

1;
__END__
# EnsEMBL module for EnsEMBL::Web::DBSQL::UserDB
# Begat by James Smith <js5@sanger.ac.uk>

=head1 NAME

EnsEMBL::Web::DBSQL::UserDB - connects to the user database

=head1 SYNOPSIS

=head2 General

Functions on the user database

=head2 connect

=head1 RELATED MODULES

See also: EnsEMBL::Web::SpeciesDefs->.pm

=head1 FEED_BACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
EnsEMBL modules. Send your comments and suggestions to one of the
EnsEMBL mailing lists.  Your participation is much appreciated.

  http://www.ensembl.org/Dev/Lists - About the mailing lists

=head2 Reporting Bugs
