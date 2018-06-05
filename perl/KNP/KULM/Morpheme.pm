# $Id: Morpheme.pm,v 1.2 2006/10/31 08:46:09 shibata Exp $
package KNP::KULM::Morpheme;
require 5.000;
use strict;
use base qw/ Juman::KULM::Morpheme /;

=head1 NAME

KNP::KULM::Morpheme - KULM �ߴ� API

=head1 SYNOPSIS

���Υ��饹��ߥ����󥰤��ƻ��Ѥ��롥

=head1 DESCRIPTION

C<KULM::KNP::M> �ߴ��Υ᥽�åɤ� C<KNP::Morpheme> ���饹���ɲä��롥

=head1 METHODS

=over 4

=item get ($attr)

���ꤵ�줿°�����֤���

=cut
sub get {
    my $this = shift;
    my $attr = shift;
    if( $attr eq "FS" ){
	$this->fstring;
    } elsif( $attr eq "F" ){
	if( @_ ){
	    ( $this->feature )[ shift ];
	} else {
	    [ $this->feature ];
	}
    } else {
	$this->SUPER::get( $attr, @_ );
    }
}

=item gets (@attr)

���ꤵ�줿°���Υꥹ�Ȥ��֤���C<all> �Ȥ������꤬��ǽ�Ǥ��롥

=cut
sub gets {
    my( $this, @attr ) = @_;
    if( $attr[0] eq "all" ){
	map( $this->$_(), @Juman::Morpheme::ATTRS, @KNP::Morpheme::ATTRS );
    } else {
	map( $this->get($_), @attr );
    }
}

1;

=back

=head1 SEE ALSO

=over 4

=item *

L<KNP::Morpheme>

=item *

L<Juman::Morpheme::KULM>

=item *

L<KULM::KNP::M>

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
