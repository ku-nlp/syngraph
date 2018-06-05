# $Id: BList.pm,v 1.2 2006/10/31 08:46:09 shibata Exp $
package KNP::KULM::BList;
require 5.000;
use strict;

=head1 NAME

KNP::KULM::BList - KULM �ߴ� API

=head1 SYNOPSIS

���Υ��饹��ߥ����󥰤��ƻ��Ѥ��롥

=head1 DESCRIPTION

C<KULM::KNP::Result> �ߴ��Υ᥽�åɤ� C<KNP::BList> ���饹���ɲä��롥

=head1 METHODS

=over 4

=item bnst ( NUM )

�� I<NUM> ���ܤ�ʸ����֤���

=item bnst

���Ƥ�ʸ��Υꥹ�Ȥ��֤���

=cut
sub bnst {
    my $this = shift;
    if( @_ ){
	( $this->bnst_list )[ @_ ];
    } else {
	$this->bnst_list;
    }
}

=item bnst_num

ʸ�����Ĺ�����֤���

=cut
sub bnst_num {
    scalar( shift->bnst_list );
}

1;

=back

=head1 SEE ALSO

=over 4

=item *

L<KNP::BList>

=item *

L<KULM::KNP::Result>

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
