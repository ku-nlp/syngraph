# $Id: Fstring.pm,v 1.2 2006/10/31 08:53:08 shibata Exp $
package KNP::Fstring;
require 5.000;
use Carp;
use strict;

=head1 NAME

KNP::Fstring - ��ħʸ����򻲾Ȥ���

=head1 SYNOPSIS

���Υ��饹��ߥ����󥰤��ƻ��Ѥ��롥

=head1 DESCRIPTION

C<KNP::Fstring> ���饹�ϡ���ħʸ����򻲾Ȥ���᥽�åɤ��󶡤��륯�饹
�Ǥ��롥

=head1 CONSTRUCTOR

���Υ��饹�ϥߥ����󥰤��ƻ��Ѥ���褦���߷פ���Ƥ��뤿�ᡤ���̤ʥ���
���ȥ饯�����������Ƥ��ʤ���

=head1 METHODS

=over 4

=item fstring

=item fstring [ STRING ]

��ħʸ������֤������������ꤵ�줿���ϡ����ꤵ�줿ʸ�������ħʸ����
�Ȥ����������롥

=cut
sub fstring {
    my $this = shift;
    if( @_ ){
	&set_fstring( $this, @_ );
    } elsif( defined $this->{fstring} ){
	$this->{fstring};
    } else {
	undef;
    }
}

=item feature

=item feature [ STRING... ]

���Ƥ���ħ�Υꥹ�Ȥ��֤������������ꤵ�줿���ϡ����ꤵ�줿��ħ�Υꥹ
�Ȥ��������롥

�����������ꥹ�Ȥ�����Ȥ��ƻ��ꤹ�뤳�ȤϤǤ��ʤ��Τǡ���ħ�����ƾõ�
���뤿��ˤϻȤ��ʤ���

=cut
sub feature {
    my $this = shift;
    if( @_ ){
	&set_feature( $this, @_ );
    } elsif( defined $this->{feature} ){
	@{$this->{feature}};
    } else {
	wantarray ? () : 0;
    }
}

=item set_fstring [ STRING ]

��ħʸ��������ꤹ�롥���ꤵ�줿ʸ������֤���

=cut
sub set_fstring {
    my( $this, $str ) = @_;
    unless( defined $str ){
	$this->{feature} = [];
	$this->{fstring} = undef;
    } else {
	$str =~ s/\A\s*//;
	$str =~ s/\s*\Z//;
	unless( $str =~ m/\A(<[^<>]*>)*\Z/ ){
	    carp "Illegal feature string: $str";
	    return undef;
	}
	$this->{fstring} = $str;
	$str =~ s/\A<//;
	$str =~ s/>\Z//;
	$this->{feature} = [ split( /></, $str ) ];
	$this->{fstring};
    }
}

=item set_feature [ STRING... ]

��ħ�Υꥹ�Ȥ����ꤹ�롥���ꤵ�줿��ħ�Υꥹ�Ȥ��֤���

=cut
sub set_feature {
    my $this = shift;
    if( grep( /[<>]/, @_ ) ){
	# <> ��ޤ�褦����ħʸ������ɲäǤ��ʤ���
	carp "Illegal feature string: @_";
	return ( wantarray ? () : 0 );
    }
    $this->{feature} = [ @_ ];
    $this->{fstring} = join( '', map( sprintf( '<%s>', $_ ), @_ ) );
    @{$this->{feature}};
}

=item push_feature ( FEATURES )

���ꤵ�줿��ħ���ɲä��롥�ɲø����ħ�ο����֤���

=cut
sub push_feature {
    my( $this, @feature ) = @_;
    scalar( $this->set_feature( $this->feature(), @feature ) );
}

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
