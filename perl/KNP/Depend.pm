# $Id: Depend.pm,v 1.1 2003/05/08 14:25:29 kawahara Exp $
package KNP::Depend;
require 5.000;
use strict;

=head1 NAME

KNP::Depend - ��¸�ط����ݻ������Ȥ���

=head1 SYNOPSIS

���Υ��饹��ߥ����󥰤��ƻ��Ѥ��롥

=head1 DESCRIPTION

C<KNP::Depend> ���饹�ϡ�����ñ��(ʸ�ᡤ����)�֤ΰ�¸�ط����ݻ������
���뤿��Υ᥽�åɤ��󶡤��륯�饹�Ǥ��롥

=head1 CONSTRUCTOR

���Υ��饹�ϥߥ����󥰤��ƻ��Ѥ���褦���߷פ���Ƥ��뤿�ᡤ���̤ʥ���
���ȥ饯�����������Ƥ��ʤ���

=head1 METHODS

=over 4

=item parent

��������֤���

=item parent [ UNIT ]

����������ꤹ�롥

=cut
sub parent {
    my $this = shift;
    if( @_ ){
	$this->{parent} = shift;
    } elsif( defined $this->{parent} ){
	$this->{parent};
    } else {
	undef;
    }
}

=item child

���긵�Υꥹ�Ȥ��֤���

=item child [ UNIT... ]

���긵�����ꤹ�롥

=cut
sub child {
    my $this = shift;
    if( @_ ){
	$this->{child} = [ @_ ];
	@{$this->{child}};
    } elsif( defined $this->{child} ){
	@{$this->{child}};
    } else {
	wantarray ? () : 0;
    }
}

=item dpndtype

��¸�ط��μ���(D,P,I,A)���֤���

=item dpndtype [ STRING ]

��¸�ط��μ�������ꤹ�롥

=cut
sub dpndtype {
    my $this = shift;
    if( @_ ){
	$this->{dpndtype} = shift;
    } elsif( defined $this->{dpndtype} ){
	$this->{dpndtype};
    } else {
	undef;
    }
}

=item id

����ñ�̤� ID ���֤���̵����ξ��� -1 ���֤���

=item id [ STRING ]

����ñ�̤� ID �����ꤹ�롥

=cut
sub id {
    my $this = shift;
    if( @_ ){
	$this->{id} = shift;
    } elsif( defined $this->{id} ){
	$this->{id};
    } else {
	-1;
    }
}

=item pstring

=item pstring [ STRING ]

����ñ�̤� I<pstring> °�����ͤ����롥���������ꤵ�줿���ϡ����ΰ���
���������롥����°���ϡ�C<KNP::DrawTree::draw_tree> �᥽�åɤ��黲�Ȥ�
��롥

=cut
sub pstring {
    my $this = shift;
    if( @_ ){
	$this->{_pstring} = shift;
    } elsif( defined $this->{_pstring} ){
	$this->{_pstring};
    } else {
	undef;
    }
}

=back

=head1 INTERNAL METHODS

�ʲ��Υ᥽�åɤϡ�����ñ�̤Υꥹ�Ȥ��ݻ����륪�֥�������
(C<KNP::BList>, C<KNP::TList>)�Υ��󥹥ȥ饯������ƤӽФ���뤳�Ȥ���
�ꤷ�Ƥ���᥽�åɤǤ��롥���̤����ѤϿ侩����ʤ���

=over 4

=item parent_id

������ñ�̤� ID ���֤���

=item parent_id [ STRING ]

������ñ�̤� ID �����ꤹ�롥

=cut
sub parent_id {
    my $this = shift;
    if( @_ ){
	my $value = shift;
	if( my $parent = $this->parent() ){
	    $parent->id( $value );
	} elsif( defined $value ){
	    $this->{_parent_id} = $value;
	} else {
	    # ̤����ͤ����ꤵ�줿���ϡ��ϥå��夫���ͤ��������
	    delete $this->{_parent_id};
	    $value;
	}
    } elsif( my $parent = $this->parent() ){
	$parent->id();
    } elsif( defined $this->{_parent_id} ){
	$this->{_parent_id};
    } else {
	-1;
    }
}

=item make_reference( LISTREF )

����ñ�̤η����褬��������ե���󥹤Ȥ��ƻ��Ȥ����褦�ˡ����֥�����
�Ȥ���������������롥������ñ�̤��ޤޤ��ꥹ�Ȥ��Ф����ե����
������Ȥ��ƸƤӽФ���

=cut
sub make_reference {
    my( $this, $list ) = @_;
    if( my $parent_id = $this->parent_id() ){
	$this->parent_id( undef );
	if( $parent_id >= 0 ){
	    my $parent = $list->[ $parent_id + $[ ];
	    $this->{parent} = $parent;
	    push( @{$parent->{child}}, $this );
	}
    }
}

=back

=head1 DESTRUCTOR

C<make_reference> �᥽�åɤˤ�äƴľ��Υ�ե���󥹤����������ȡ���
��� Garbage Collection �ˤ�äƤϡ����꤬�������ʤ��ʤ롥��������
���򤱤뤿��ˡ�����Ū�˥�ե���󥹤��˲����� destructor ��������Ƥ�
�롥

=cut
sub DESTROY {
    my( $this ) = @_;
    delete $this->{parent};
    delete $this->{child};
}

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
