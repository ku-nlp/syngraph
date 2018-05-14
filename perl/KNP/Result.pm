# $Id: Result.pm,v 1.2 2006/10/31 08:53:08 shibata Exp $
package KNP::Result;
require 5.004_04; # For base pragma.
use KNP::Bunsetsu;
use KNP::Morpheme;
use KNP::Tag;
use strict;
use base qw/ KNP::BList /;
use vars qw/ %DEFAULT /;

=head1 NAME

KNP::Result - ��ʸ���Ϸ�̥��֥�������

=head1 SYNOPSIS

  $result = new KNP::Result( "* -1D <BGH:����>\n...\nEOS\n" );

=head1 DESCRIPTION

��ʸ���Ϸ�̤��ݻ����륪�֥������ȡ�

=head1 CONSTRUCTOR

=over 4

=item new ( RESULT )

KNP �ν���ʸ���󡤤ޤ��ϡ�����ʸ�����Ԥ�ñ�̤Ȥ��Ƴ�Ǽ���줿�ꥹ�Ȥ�
�Ф����ե���� RESULT ������Ȥ��ƸƤӽФ��ȡ����ι�ʸ���Ϸ�̤�ɽ
�����֥������Ȥ��������롥

=item new ( OPTIONS )

�ʲ��γ�ĥ���ץ�������ꤷ�ƥ��󥹥ȥ饯����ƤӽФ���

=over 4

=item result => RESULT

KNP �ν���ʸ���󡤤ޤ��ϡ�����ʸ�����Ԥ�ñ�̤Ȥ��Ƴ�Ǽ���줿�ꥹ�Ȥ�
�Ф����ե���󥹤���ꤹ�롥

=item pattern => STRING

��ʸ���Ϸ�̤�ü���뤿��Υѥ��������ꤹ�롥

=item bclass => NAME

ʸ�ᥪ�֥������Ȥ���ꤹ�롥̵����ξ��ϡ�C<KNP::Bunsetsu> ���Ѥ��롥

=item mclass => NAME

�����ǥ��֥������Ȥ���ꤹ�롥̵����ξ��ϡ�C<KNP::Morpheme> ���Ѥ��롥

=item tclass => NAME

�������֥������Ȥ���ꤹ�롥̵����ξ��ϡ�C<KNP::Tag> ���Ѥ��롥

=back

=cut
%DEFAULT = ( pattern => '^EOS$',
	     bclass  => 'KNP::Bunsetsu',
	     mclass  => 'KNP::Morpheme',
	     tclass  => 'KNP::Tag' );

sub new {
    my $class = shift;

    my( %opt ) = %DEFAULT;
    if( @_ == 1 ){
	$opt{result} = shift;
    } else {
	while( @_ ){
	    my $key = shift;
	    my $val = shift;
	    $key =~ s/^-+//;
	    $opt{lc($key)} = $val;
	}
    }
    my $result  = $opt{result};
    my $pattern = $opt{pattern};
    my $bclass  = $opt{bclass};
    my $mclass  = $opt{mclass};
    my $tclass  = $opt{tclass};
    return undef unless( $result and $pattern and $bclass and $mclass and $tclass );

    # ʸ����ľ�ܻ��ꤵ�줿���
    $result = [ map( "$_\n", split( /\n/, $result ) ) ] unless ref $result;

    my $this = { all => join( '', @$result ) };
    bless $this, $class;
    return $this unless $pattern;

    # ��ʸ���Ϸ�̤���Ƭ�˴ޤޤ�Ƥ��륳���Ȥȥ��顼����ʬ�������
    my( $str, $comment, $error );
    while( defined( $str = shift @$result ) ){
	if( $str =~ /^#/ ){
	    $comment .= $str;
	} elsif( $str =~ m!^;;! ){
	    $error .= $str;
	} else {
	    unshift( @$result, $str );
	    last;
	}
    }

    while( defined( $str = shift @$result ) ){
	if( $str =~ m!$pattern! and @$result == 0 ){
	    $this->{_eos} = $str;
	    last;
	} elsif( $str =~ m!^;;! ){
	    $error .= $str;
	} elsif( $str =~ m!^\*! ){
	    $this->push_bnst( $bclass->new( $str, scalar($this->bnst) ) );
	} elsif( $str =~ m!^\+! ){
	    $this->push_tag( $tclass->new( $str, scalar($this->tag) ) );
	} else {
	    $this->push_mrph( $mclass->new( $str, scalar($this->mrph) ) );
	    my $fstring = ( $this->mrph )[-1]->fstring;
	    while ( $fstring =~ /<(ALT-[^>]+)>/g ){ # ALT
		( $this->mrph )[-1]->push_doukei( $mclass->new( $1, scalar($this->mrph) ) );
	    }
	}
    }

    # ��������������Ф�
    my( @bnst ) = $this->bnst;
    for my $bnst ( @bnst ){
	$bnst->make_reference( \@bnst );
    }
    my( @tag ) = $this->tag;
    for my $tag ( @tag ){
	$tag->make_reference( \@tag );
    }

    # �񤭹��ߤ�ػߤ���
    $this->set_readonly();

    $this->{comment} = $comment;
    $this->{error}   = $error;
    $this;
}

=back

=head1 METHODS

��ʸ���Ϸ�̤ϡ��оݤȤʤ�ʸ��ʸ��ñ�̤�ʬ�򤷤��ꥹ�Ȥȸ��뤳�Ȥ��Ǥ�
�롥���Τ��ᡤ�ܥ��饹�� C<KNP::BList> ���饹��Ѿ�����褦�˼�������
�Ƥ��ꡤ�ʲ��Υ᥽�åɤ����Ѳ�ǽ�Ǥ��롥

=over 4

=item bnst

ʸ�������Ф���

=item tag

���������Ф���

=item mrph

�����������Ф���

=back

�����Υ᥽�åɤξܺ٤ˤĤ��Ƥϡ�L<KNP::BList> �򻲾ȤΤ��ȡ�

�ä��ơ��ʲ��Υ᥽�åɤ��������Ƥ��롥

=over 4

=item all

��ʸ���Ϸ�̤���ʸ������֤���

=cut
sub all {
    my( $this ) = @_;
    $this->{all} || undef;
}

=item comment

��ʸ���Ϸ����Υ����Ȥ��֤���

=cut
sub comment {
    my( $this ) = @_;
    $this->{comment} || undef;
}

=item error

��ʸ���Ϸ����Υ��顼��å��������֤���

=cut
sub error {
    my( $this ) = @_;
    $this->{error} || undef;
}

=item id

��ʸ���Ϸ��ID�����롥

=cut
sub id {
    my $this = shift;
    if( @_ ){
	$this->set_id( @_ );
    } else {
	unless( defined $this->{_id} ){
	    $this->{_id} = $this->{comment} =~ m/# S-ID:([-A-z0-9]+)/ ? $1 : -1;
	}
	$this->{_id};
    }
}

=item set_id ( ID )

��ʸ���Ϸ��ID�����ꤹ�롥

=cut
sub set_id {
    my( $this, $id ) = @_;
    if( defined $this->{comment} ){
	( $this->{comment} =~ s/# S-ID:[-A-z0-9]+/# S-ID:$id/ )
	    or ( $this->{comment} = "S-ID:$id\n" . $this->{comment} );
    } else {
	$this->{comment} = "S-ID:$id\n";
    }
    $this->{_id} = $id;
}

=item spec

��ʸ���Ϸ�̤�ɽ������ʸ������������롥

=cut
sub spec {
    my( $this ) = @_;
    sprintf( "# S-ID:%s\n%s%s",
	     $this->id,
	     $this->KNP::BList::spec(),
	     $this->{_eos} );
}

=back

=head1 SEE ALSO

=over 4

=item *

L<KNP::BList>

=back

=head1 AUTHOR

=over 4

=item
�ڲ� ��̭ <tsuchiya@pine.kuee.kyoto-u.ac.jp>

=cut

1;
__END__
# Local Variables:
# mode: perl
# coding: euc-japan
# use-kuten-for-period: nil
# use-touten-for-comma: nil
# End:
