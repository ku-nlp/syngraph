# $Id: TList.pm,v 1.2 2006/10/31 08:46:09 shibata Exp $
package KNP::KULM::TList;
require 5.000;
use strict;

=head1 NAME

KNP::KULM::TList - KULM �ߴ� API

=head1 SYNOPSIS

���Υ��饹��ߥ����󥰤��ƻ��Ѥ��롥

=head1 DESCRIPTION

C<KULM> �ߴ��Υ᥽�åɤ� C<KNP::TList> ���饹���ɲä��롥

=head1 METHODS

=over 4

=item tag ( NUM )

�� I<NUM> ���ܤΥ������֤���

=item tag

���ƤΥ����Υꥹ�Ȥ��֤���

=cut
sub tag {
    my $this = shift;
    if( @_ ){
	( $this->tag_list )[ @_ ];
    } else {
	$this->tag_list;
    }
}

=item tag_num

�������Ĺ�����֤���

=cut
sub tag_num {
    scalar( shift->tag_list );
}

1;

=back

=head1 SEE ALSO

=over 4

=item *

L<KNP::TList>

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
