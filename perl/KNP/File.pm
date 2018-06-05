package KNP::File;
require 5.000;
use English qw/ $PERL_VERSION /;
use IO::File;
use KNP::Result;
use POSIX qw/ SEEK_SET O_RDONLY O_CREAT /;
use strict;

=head1 NAME

KNP::File - ��ʸ���Ϸ�̤γ�Ǽ����Ƥ���ե����������⥸�塼��

=head1 SYNOPSIS

 $knp = new KNP::File( $file ) or die;
 while( $result = $knp->each() ){
     print $result->spec;
 }

=head1 CONSTRUCTOR

=over 4

=item new ( FILE )

��ʸ���Ϸ�̤γ�Ǽ����Ƥ���ե��������ꤷ�ơ����֥������Ȥ�������
�롥

=item new ( OPTIONS )

��ĥ���ץ�������ꤷ�ƥ��֥������Ȥ��������롥�㤨�С���ʸ���Ϸ��
�ե�����˴ޤޤ�Ƥ�����Ϸ�̤�ʸ ID �Υǡ����١����ե��������ꤹ��
ɬ�פ�������ˤϡ��ʲ��Τ褦�˻��ꤹ�뤳�Ȥ��Ǥ��롥

  Example:

    $knp = new KNP::File( file => 'path_to_file',
                          dbfile => 'path_to_dbfile' );

=cut
sub new {
    my $class = shift;
    my %opt;
    if( @_ == 1 ){
	$opt{file} = shift;
    } else {
	while( @_ ){
	    my $key = shift;
	    my $val = shift;
	    $key =~ s/^-+//;
	    $opt{lc($key)} = $val;
	}
    }

    if( my $fh = new IO::File( $opt{file}, "r" ) ){
	&set_encoding( $fh );
	my $new = { name    => $opt{file},
		    dbname  => $opt{dbfile}  || $opt{file}.'.db',
		    pattern => $opt{pattern} || $KNP::Result::DEFAULT{pattern},
		    bclass  => $opt{bclass}  || $KNP::Result::DEFAULT{bclass},
		    mclass  => $opt{mclass}  || $KNP::Result::DEFAULT{mclass},
		    tclass  => $opt{tclass}  || $KNP::Result::DEFAULT{tclass},
		    _file_handle => $fh };
	bless $new, $class;
    } else {
	undef;
    }
}

=back

=head1 METHODS

=over 4

=item name

���Ȥ��Ƥ���ե�����Υե�����̾���֤���

=cut
sub name {
    my( $this ) = @_;
    $this->{name};
}

=item each

��Ǽ����Ƥ��빽ʸ���Ϸ�̤�ʸ��ñ�̤Ȥ��ƽ���֤���

=cut
sub each {
    my( $this ) = @_;
    my $pattern = $this->{pattern};
    my $fh = $this->{_file_handle};
    $this->setpos( 0 )
	unless $this->{_each_pos} and ( $this->getpos == $this->{_each_pos} );
    my @buf;
    while( <$fh> ){
	push( @buf, $_ );
	if( m!$pattern! ){
	    $this->{_each_pos} = $this->getpos;
	    return &_result( $this, \@buf );
	}
    }
    $this->{_each_pos} = 0;
    undef;
}

sub _result {
    my( $this, $spec ) = @_;
    KNP::Result->new( result  => $spec,
		      pattern => $this->{pattern},
		      bclass  => $this->{bclass},
		      mclass  => $this->{mclass},
		      tclass  => $this->{tclass} );
}

=item look

ʸ ID ����ꤷ�ơ���ʸ���Ϸ�̤���Ф���

=cut
sub look {
    my( $this, $sid ) = @_;
    unless( $this->{_db} ){
	my %db;
	if( -f $this->dbname ){
	    require Juman::DB_File;
	    tie( %db, 'Juman::DB_File', $this->dbname, O_RDONLY ) or return undef;
	} else {
	    &_make_hash( $this, \%db );
	}
	$this->{_db} = \%db;
    }
    if( my $spec = $this->{_db}->{$sid} ){
	my( $pos, $len ) = split( /,/, $spec );
	$this->setpos( $pos );
	read( $this->{_file_handle}, $spec, $len );
	&_result( $this, $spec );
    } else {
	undef;
    }
}

=item makedb

�ե�����˴ޤޤ�Ƥ��빽ʸ���Ϸ�̤�ʸ ID �Υǡ����١�����������롥

=cut
sub makedb {
    my( $this ) = @_;

    my %db;
    require Juman::DB_File;
    tie( %db, 'Juman::DB_File', $this->dbname, O_CREAT ) or return 0;
    &_make_hash( $this, \%db ) or return 0;
    untie %db;
    1;
}

# ʸ ID ��Ϣ�������������������ؿ�
sub _make_hash {
    my( $this, $hash ) = @_;

    %$hash = ();			# Ϣ�����������
    $this->setpos( 0 ) or return 0;
    my $pos = 0;
    my $pattern = $this->{pattern};
    my $fh = $this->{_file_handle};

  OUTER:
    while (1) {
	my $len = 0;
	my $id;
	while( <$fh> ){
	    $len += length;
	    if( m!^# S-ID:([-A-z0-9]+)! ){
		$id = $1;
	    }elsif( m!$pattern! ){
		$id and $hash->{ $id } = sprintf( "%d,%d", $pos, $len );
		$pos = $this->getpos;
		next OUTER;
	    }
	}
	$this->{_each_pos} = 0;
	last;
    }
    1;
}

=item dbname

ʸ ID �ǡ����١����Υե�����̾���֤���

=cut
sub dbname {
    my( $this ) = @_;
    $this->{dbname};
}

=item getpos

�����Ƥ���ե�����θ��ߤΥե�����ݥ��󥿤ΰ��֤��֤���

=cut
sub getpos {
    my( $this ) = @_;
    my $fh = $this->{_file_handle};
    $fh->tell;
}

=item setpos ( POS )

�����Ƥ���ե�����Υե�����ݥ��󥿤ΰ��֤� C<POS> �˰�ư���롥������
�ˤ� 1 �򡤼��Ի��ˤ� 0 ���֤���

=cut
sub setpos {
    my( $this, $pos ) = @_;
    my $fh = $this->{_file_handle};
    $fh->seek( $pos, SEEK_SET );
}

=back

=head1 MEMO

Perl-5.8 �ʹߤξ�硤�ҥץ����Ȥ��̿��ˤϡ� C<encoding> �ץ饰�ޤǻ�
�ꤵ�줿ʸ�������ɤ��Ȥ��ޤ���

=cut
BEGIN {
    if( $PERL_VERSION > 5.008 ){
	require Juman::Encode;
	Juman::Encode->import( qw/ set_encoding / );
    } else {
	*{Juman::Fork::set_encoding} = sub { undef; };
    }
}

=head1 SEE ALSO

=over 4

=item *

L<KNP::Result>

=back

=head1 AUTHOR

=over 4

=item
�ڲ� ��̭ <tsuchiya@pine.kuee.kyoto-u.ac.jp>

=cut

1;
