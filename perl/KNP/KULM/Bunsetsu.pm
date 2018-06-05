# $Id: Bunsetsu.pm,v 1.2 2006/10/31 08:46:09 shibata Exp $
package KNP::KULM::Bunsetsu;
require 5.000;
use Carp;
use strict;

=head1 NAME

KNP::KULM::Bunsetsu - KULM �ߴ� API

=head1 SYNOPSIS

���Υ��饹��ߥ����󥰤��ƻ��Ѥ��롥

=head1 DESCRIPTION

C<KULM::KNP::B> �ߴ��Υ᥽�åɤ� C<KNP::Bunsetsu> ���饹���ɲä��롥

=head1 METHODS

=over 4

=item get ($attr)

���ꤵ�줿°�����֤���

=cut
sub get {
    my $this = shift;
    my $attr = shift;

    # �ߴ������ݤĤ���, $m->get( [ F => $j ] ) �Ȥ��������λ�������
    # �դ���褦�ˤ��Ƥ��롥�����������λ��ͤ� KULM::KNP::M �λ��ͤȤ�
    # ���礷�Ƥ��ʤ��Τǡ��Х��β�ǽ�����⤤��
    if( ref $attr eq 'ARRAY' ){
	( $attr, @_ ) = @{$attr};
    }

    if( $attr eq "ID" ){
	$this->id;
    } elsif( $attr eq "P" ){
	$this->parent;
    } elsif( $attr eq "D" ){
	$this->dpndtype;
    } elsif( $attr eq "C" ){
	[ $this->child ];
    } elsif( $attr eq "ML" ){
	[ $this->mrph_list ];
    } elsif( $attr eq "FS" ){
	$this->fstring;
    } elsif( $attr eq "F" ){
	if( @_ ){
	    ( $this->feature )[ shift ];
	} else {
	    [ $this->feature ];
	}
    } elsif( $attr eq "string" ){
	join( "", map( $_->midasi, $this->mrph_list ) );
    } elsif( $attr eq "p_id" ){
	$this->parent ? $this->parent->id : -1;
    } else {
	croak "Unknown attribute: $attr";
    }
}

=item gets (@attr)

���ꤵ�줿°���Υꥹ�Ȥ��֤���C<all> �Ȥ������꤬��ǽ�Ǥ��롥

=cut
sub gets {
    my( $this, @attr ) = @_;
    if( $attr[0] eq "all" ){
	map( $this->get($_), qw/ ID p_id D string FS / );
    } else {
	map( $this->get($_), @attr );
    }
}

=item string ($delimiter, @attr)

���ꤵ�줿°���� C<$delimiter> �Ƿ�礷��ʸ������֤���

=cut
sub string {
    my $this = shift;
    my $delimiter = shift;
    join( $delimiter || " ", grep( defined($_), $this->gets( @_ ? @_ : "string" ) ) );
}

1;

=back

=head1 SEE ALSO

=over 4

=item *

L<KNP::Bunsetsu>

=item *

L<KULM::KNP::B>

=back

=head1 AUTHOR

=over 4

=item
�ڲ� ��̭ <tsuchiya@pine.kuee.kyoto-u.ac.jp>

=cut

__END__
# Local Variables:
# mode: perl
# coding: euc-japan
# use-kuten-for-period: nil
# use-touten-for-comma: nil
# End:
