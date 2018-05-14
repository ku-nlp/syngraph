# $Id: KNP.pm,v 1.3 2007/07/06 09:54:13 murawaki Exp $
package KNP;
require 5.004_04; # For base pragma.
use Carp;
use English qw/ $LIST_SEPARATOR /;
use Juman;
use KNP::Result;
use strict;
use base qw/ KNP::Obsolete Juman::Process /;
use vars qw/ $VERSION %DEFAULT /;

=head1 NAME

KNP - ��ʸ���Ϥ�Ԥ��⥸�塼��

=head1 SYNOPSIS

 use KNP;
 $knp = new KNP;
 $result = $knp->parse( "����ʸ��ʸ���Ϥ��Ƥ���������" );
 print $result->all;

=head1 DESCRIPTION

C<KNP> �ϡ�KNP ���Ѥ��ƹ�ʸ���Ϥ�Ԥ��⥸�塼��Ǥ��롥

ñ��˹�ʸ���Ϥ�Ԥ������ʤ�С�C<KNP::Simple> �����ѤǤ��롥
C<KNP::Simple> �ϡ�C<KNP> �⥸�塼��Υ�åѡ��Ǥ��ꡤ����ñ�˹�ʸ��
�ϴ�����ѤǤ���褦���߷פ���Ƥ��롥

=head1 CONSTRUCTOR

C<KNP> ���֥������Ȥ��������륳�󥹥ȥ饯���ϡ��ʲ��ΰ���������դ��롥

=head2 Synopsis

    $knp = new KNP
             [ -Server        => string,]
             [ -Port          => integer,]
             [ -Command       => string,]
             [ -Timeout       => integer,]
             [ -Option        => string,]
             [ -Rcfile        => filename,]
             [ -IgnorePattern => string,]
             [ -JumanServer   => string,]
             [ -JumanPort     => integer,]
             [ -JumanCommand  => string,]
             [ -JumanOption   => string,]

=head2 Options

=over 4

=item -Server

KNP �����С��Υۥ���̾����ά���줿���ϡ��Ķ��ѿ� C<KNPSERVER> �ǻ���
���줿�����С������Ѥ���롥�Ķ��ѿ�����ꤵ��Ƥ��ʤ����ϡ�KNP ���
�ץ����Ȥ��ƸƤӽФ���

=item -Port

KNP �����С��Υݡ����ֹ桥

=item -Command

KNP �μ¹ԥե�����̾��KNP �����С������Ѥ��ʤ����˻��Ȥ���롥

=item -Timeout

�����С��ޤ��ϻҥץ������̿���������Ԥ����֡�

=item -Option

KNP ��¹Ԥ���ݤΥ��ޥ�ɥ饤���������ά�������ϡ�
C<$KNP::DEFAULT{option}> ���ͤ��Ѥ����롥

������������ե��������ꤹ�� C<-r> ���ץ����ȡ�KNP �ˤ�ä�̵�뤵
����Ƭ�ѥ��������ꤹ�� C<-i> ���ץ����ˤĤ��Ƥϡ����줾����̤� 
C<-Rcfile>, C<-IgnorePattern> �ˤ�äƻ��ꤹ��٤��Ǥ��롥

=item -Rcfile

KNP ������ե��������ꤹ�륪�ץ����

���Υ��ץ����ȡ�KNP �����С������Ѥ�ξΩ���ʤ����Ȥ�¿�����äˡ�����
�С������Ѥ��Ƥ��뼭��Ȱ㤦�������ꤷ�Ƥ�������ե�����ϡ��տޤ���
�̤�ˤ�ư��ʤ���

=item -IgnorePattern

KNP �ˤ�ä�̵�뤵����Ƭ�ѥ�����

=item -JumanServer

=item -JumanPort

=item -JumanCommand

=item -JumanOption

=item -JumanRcfile

Juman ��ƤӽФ����Υ��ץ���������Ū�˻��ꤹ�뤿��Υ��ץ����

=back

=head1 METHODS

=over 4

=item knp( OBJ )

=item parse( OBJ )

ʸ����ޤ��Ϸ������󥪥֥������� OBJ ���оݤȤ��ƹ�ʸ���Ϥ�Ԥ�����ʸ
���Ϸ�̥��֥������Ȥ��֤���

��������ʸ���󤬶�ʸ����Ǥ��ä��ꡤʸ�������Ƭ��ʸ���� C<#> �Ǥ��ä�
�ꤷ�����ˤϡ�ʸ�����̵�뤵�� undef ���֤��ͤȤʤ롥

�ޤ�����ʸ���������̿Ū�ʥ��顼��ȯ���������� undef ���֤������ξ�
��ϡ�����ľ��� C<error> �᥽�åɤ��Ѥ��뤳�Ȥˤ�äơ��ºݤ�ȯ������
���顼���Τ뤳�Ȥ��Ǥ��롥

�������äơ�C<parse> �᥽�åɤ��֤��ͤ򡤴������İ����˽������뤿���
�ϡ��ʲ��Τ褦�ʥץ���बɬ�פǤ��롥

  Example:

    $result = $knp->parse( $str );
    if( $result ){
        # ��ʸ���Ϥ������������
        if( $result->error() ){
            # ����������ʸ������˲��餫�Υ��顼��å�������
            # ���Ϥ��줿���
        }
        else {
            # �����˹�ʸ���Ϥ���λ�������
        }
    } else {
        if( $knp->error() ){
            # ��ʸ���������̿Ū�ʥ��顼��ȯ���������
        }
        else {
            # �оݤȤʤ�ʸ����̵�뤵�졤�������Ԥ��ʤ��ä����
        }
    }

����Ū�ˤϰʲ��Τ褦�ʥץ����ǽ�ʬ������

  Example:

    $result = $knp->parse( $str );
    if( $result ){
        # ��ʸ���Ϥ������������
    }

=item parse_string( STRING )

ʸ������оݤȤ��ƹ�ʸ���Ϥ�Ԥ�����ʸ���ϥ��֥������Ȥ��֤���

=item parse_mlist( MLIST )

�������󥪥֥������Ȥ��оݤȤ��ƹ�ʸ���Ϥ�Ԥ�����ʸ���Ϸ�̥��֥�����
�Ȥ��֤���

=item result

ľ���ι�ʸ���Ϸ�̥��֥������Ȥ��֤���

=item error

ľ������̿Ū�ʥ��顼���֤���

=item detail( [TYPE] )

C<-detail> ���ץ�������ꤷ�����˸¤�ͭ���Ȥʤ�᥽�åɡ�

=item juman( STRING )

ʸ���������ǲ��Ϥ��������ǲ��Ϸ�̥��֥������Ȥ��֤���

=back

=head1 ENVIRONMENT

=over 4

=item KNPSERVER

�Ķ��ѿ� C<KNPSERVER> �����ꤵ��Ƥ�����ϡ����ꤵ��Ƥ���ۥ��Ȥ� 
KNP �����С��Ȥ������Ѥ��롥

=back

=head1 SEE ALSO

=over 4

=item *

L<KNP::Simple>

=item *

L<KNP::Result>

=back

=head1 HISTORY

This module is the completely rewritten version of the original module
written by Sadao Kurohashi <kuro@i.kyoto-u.ac.jp>.

=head1 AUTHOR

=over 4

=item
TSUCHIYA Masatoshi <tsuchiya@pine.kuee.kyoto-u.ac.jp>

=back

=head1 COPYRIGHT

���ѵڤӺ����ۤˤĤ��Ƥ� GPL2 �ޤ��� Artistic License �˽��äƤ���������

=cut


### �С������ɽ��
$VERSION = '0.4.9';

# �������ޥ������ѿ�
%DEFAULT =
    ( command => &Juman::Process::which_command('knp'),
      server  => $ENV{KNPSERVER} || '',		# KNP �����С��Υۥ���̾
      port    => 31000,				# KNP �����С��Υݡ����ֹ�
      timeout => 60,				# KNP �����С��α������Ԥ�����
      option  => '-tab',			# KNP ���Ϥ���륪�ץ����
      rcfile  => $ENV{HOME}.'/.knprc',
      bclass  => $KNP::Result::DEFAULT{bclass},
      mclass  => $KNP::Result::DEFAULT{mclass},
      tclass  => $KNP::Result::DEFAULT{tclass}, );
while( my( $key, $value ) = each %Juman::DEFAULT ){
    $DEFAULT{"juman$key"} = $value;
}



#----------------------------------------------------------------------
#		Constructor
#----------------------------------------------------------------------

# KNP ��ҥץ����Ȥ��Ƽ¹Ԥ��Ƥ����硤ɸ����ϤΥХåե���󥰤ˤ��
# �ƽ��Ϥ���Ťˤʤ�ʤ��褦�ˤ��뤿��Τ��ޤ��ʤ�
sub BEGIN {
    unless( $DEFAULT{server} ){
	require FileHandle or die;
	STDOUT->autoflush(1);
    }
}

sub new {
    my $class = shift @_;
    my $this = {};
    bless $this, $class;

    if( @_ == 1 ){
	# ��С������η����ǸƤӽФ��줿���ν���
	my( $argv ) = @_;
	$this->setup( $argv, \%DEFAULT );
    } else {
	# �����������ǸƤӽФ��줿���ν���
	my( %option ) = @_;
	$this->setup( \%option, \%DEFAULT );
    }

    if( $this->{OPTION}->{rcfile} and $this->{OPTION}->{server} ){
	carp "Rcfile option may not work with KNP server";
    }

    $this;
}

sub close {
    my( $this ) = @_;
    $this->{PREVIOUS} = [];
    $this->Juman::Process::close();
}



#----------------------------------------------------------------------
#		��ʸ���Ϥ�Ԥ��᥽�å�
#----------------------------------------------------------------------
sub knp { &parse(@_); }
sub parse {
    my( $this, $object ) = @_;
    if( ref($object) and $object->isa('Juman::MList') ){
	&parse_mlist( $this, $object );
    } else {
	&parse_string( $this, $object );
    }
}

# ʸ������оݤȤ��ơ���ʸ���Ϥ�Ԥ��᥽�å�
sub parse_string {
    my( $this, $str ) = @_;
    
    # ����Ȳ��ԤΤߤ���ʤ�����ʸ��̵�뤵���
    return &_set_error( $this, undef ) if $str =~ m/^\s*$/s;

    # "#" �ǻϤޤ�����ʸ��̵�뤵���
    return &_set_error( $this, undef ) if $str =~ /^\#/;

    &_real_parse( $this,
		  &juman_lines( $this, $str ),
		  $str );
}

# �������󥪥֥������Ȥ��оݤȤ��ơ���ʸ���Ϥ�Ԥ��᥽�å�
sub parse_mlist {
    my( $this, $mlist ) = @_;
    &_real_parse( $this,
		  [ $mlist->Juman::MList::spec(), "EOS\n" ],
		  join( '', map( $_->midasi(), $mlist->mrph ) ) );
}

# �ºݤι�ʸ���Ϥ�Ԥ������ؿ�
sub _real_parse {
    my( $this, $array, $str ) = @_;

    return &_set_error( $this, ";; TIMEOUT is occured when Juman was called.\n" )
	unless( @{$array} );

    # UTF�ե饰������å�����
    if (utf8::is_utf8($str)) {
	require Encode;
	foreach my $str (@{$array}) {
	    $str = Encode::encode('euc-jp', $str);
	}
	$this->{input_is_utf8} = 1;
    }
    else {
	$this->{input_is_utf8} = 0;
    }

    # Parse ERROR �ʤɤ�ȯ���������˸�����Ĵ�٤뤿�ᡤ��ʸ���Ϥ���ʸ
    # ���������¸���Ƥ�����
    unshift( @{$this->{PREVIOUS}}, $str );
    splice( @{$this->{PREVIOUS}}, 10 ) if @{$this->{PREVIOUS}} > 10;

    # ��ʸ����
    my @error;
    my $counter = 0;
    my $pattern = $this->pattern();
  PARSE:
    my $sock = $this->open();
    $sock->print( @$array );
    $counter++;

    # ��ʸ���Ϸ�̤��ɤ߽Ф�
    my( @buf );
    my $skip = ( $this->{OPTION}->{option} =~ /\-detail/ ) ? 1 : 0;
    while( defined( $str = $sock->getline ) ){
	if ($this->{input_is_utf8}) {
	    $str = Encode::decode('euc-jp', $str);
	}
	push( @buf, $str );
	last if $str =~ /$pattern/ and ! $skip--;
    }
#    die "Mysterious error: KNP server or process gives no response" unless @buf;

    # ��ʸ���Ϸ�̤κǸ�� EOS �ΤߤιԤ�̵�����ϡ��ɤ߽Ф���˥���
    # �ॢ���Ȥ�ȯ�����Ƥ��롥
    unless( @buf and $buf[$#buf] =~ /$pattern/ ){
 	if( $counter == 1 ){
 	    push( @error, ";; TIMEOUT is occured.\n" );
	    my $i = $[;
	    push( @error,
		  map( sprintf(";; TIMEOUT:%02d:%s\n",$i++,$_), @{$this->{PREVIOUS}} ) );
 	}
	$this->close();
	goto PARSE if( $counter <= 1 );
	return &_set_error( $this, join( '', @error ) );
    }

    # "Cannot detect consistent CS scopes." �Ȥ������顼�ξ��ϡ�KNP 
    # �ΥХ��Ǥ����ǽ��������Τǡ���ö KNP ��Ƶ�ư���롥
    if( grep( /^;; Cannot detect consistent CS scopes./, @buf ) ){
 	if( $counter == 1 ){
 	    push( @error, ";; Cannot detect consistent CS scopes.\n" );
	    my $i = $[;
	    push( @error,
		  map( sprintf(";; CS:%02d:%s\n",$i++,$_), @{$this->{PREVIOUS}} ) );
 	}
 	$this->close();
 	goto PARSE if( $counter <= 1 );
    }

    # -detail ���ץ���󤬻��ꤵ��Ƥ�����
    if( $this->{OPTION}->{option} =~ /\-detail/ ){
	my( $str, @mrph, @bnst );
	while( defined( $str = shift @buf ) ){
	    push( @mrph, $str );
	    last if $str =~ /$pattern/;
	}
	while( defined( $str = shift @buf ) ){
	    if( $str =~ /^#/ ){
		unshift( @buf, $str );
		last;
	    }
	    push( @bnst, $str );
	}
	$this->{DETAIL} = { mrph   => join( '', @mrph ),
			    bnst   => join( '', @bnst ),
			    struct => join( '', @buf ) };
    }

    # ��ʸ���Ϸ�̤�������롥
    unshift( @buf, @error );
    &_internal_analysis( $this, \@buf );
}



#----------------------------------------------------------------------
#		�����ǲ��Ϥ�Ԥ��᥽�å�
#----------------------------------------------------------------------
sub _new_juman {
    my( $this ) = @_;
    unless( $this->{JUMAN} ){
	my %opt;
	while( my( $key, $value ) = each %{$this->{OPTION}} ){
	    $key =~ s/^juman// and $opt{$key} = $value;
	}
	$this->{JUMAN} = new Juman( %opt );
    }
}

sub juman_lines {
    my( $this, $str ) = @_;
    &_new_juman($this);
    $this->{JUMAN}->juman_lines( $str );
}

sub juman {
    my( $this, $str ) = @_;
    &_new_juman($this);
    $this->{JUMAN}->juman( $str );
}



#----------------------------------------------------------------------
#		��ʸ���Ϸ�̤���Ϥ���ؿ�
#----------------------------------------------------------------------
sub analysis {
    my( $this, @result ) = @_;
    &_internal_analysis( $this, \@result );
}

sub _internal_analysis {
    my( $this, $result ) = @_;

    my $pattern = $this->{OPTION}->{option} =~ /\-(?:tab|bnst)\b/ ? $this->pattern() : '';
    $result = new KNP::Result( result  => $result,
			       pattern => $pattern,
			       bclass  => $this->{OPTION}->{bclass},
			       mclass  => $this->{OPTION}->{mclass},
			       tclass  => $this->{OPTION}->{tclass} );

    # result �᥽�åɤ��黲�ȤǤ���褦����¸
    $this->{RESULT} = $result;

    # NOTE: �����Υϥå��幽¤��ľ�ܥ����������Ƥ��륹����ץȤθ�����
    # �����Τ���ξ��ٹ�
    $this->{ALL}     = $result->all;
    $this->{COMMENT} = $result->comment;
    $this->{ERROR}   = $result->error;
    $this->{MRPH}    = [ $result->mrph ];
    $this->{BNST}    = [ $result->bnst ];

    delete $this->{_fatal_error};
    $result;
}

sub _set_error {
    my( $this, $error ) = @_;

    # �¹Է�̤�ꥻ�å�
    delete $this->{RESULT};

    # �����ߴ����Τ���Υϥå������
    delete $this->{ALL};
    delete $this->{COMMENT};
    delete $this->{ERROR};
    delete $this->{MRPH};
    delete $this->{BNST};

    if( $error ){
	$this->{_fatal_error} = $error;
    } else {
	delete $this->{_fatal_error};
    }
    undef;
}



#----------------------------------------------------------------------
#		��ʸ���Ϸ�̤���Ф��᥽�å�
#----------------------------------------------------------------------
sub detail {
    if( @_ == 1 ){
	my( $this ) = @_;
	$this->{DETAIL};
    } elsif( @_ == 2 ){
	my( $this, $type ) = @_;
	if( defined $this->{DETAIL}{$type} ){
	    $this->{DETAIL}{$type};
	} else {
	    carp "Unknown type ($type)";
	    undef;
	}
    } else {
        local $LIST_SEPARATOR = ', ';
        carp "Too many arguments (@_)";
	undef;
    }
}

sub result {
    my( $this ) = @_;
    $this->{RESULT} || undef;
}

sub error {
    my( $this ) = @_;
    $this->{_fatal_error} || undef;
}

1;
__END__
# Local Variables:
# mode: perl
# coding: euc-japan
# use-kuten-for-period: nil
# use-touten-for-comma: nil
# End:
