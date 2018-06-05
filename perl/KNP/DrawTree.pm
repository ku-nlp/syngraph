# $Id: DrawTree.pm,v 1.2 2006/10/31 08:53:08 shibata Exp $
package KNP::DrawTree;
require 5.000;
use Carp;
use bytes ();
use strict;

=head1 NAME

KNP::DrawTree - ��¸�ط����ڹ�¤��ɽ������

=head1 SYNOPSIS

���Υ��饹��ߥ����󥰤��ƻ��Ѥ��롥

=head1 DESCRIPTION

C<KNP::DrawTree> ���饹�ϡ�����ñ��(ʸ�ᡤ����)�֤ΰ�¸�ط����ڹ�¤��
����ɽ�����뤿��Υ᥽�åɤ��󶡤��륯�饹�Ǥ��롥

=head1 CONSTRUCTOR

���Υ��饹�ϥߥ����󥰤��ƻ��Ѥ���褦���߷פ���Ƥ��뤿�ᡤ���̤ʥ���
���ȥ饯�����������Ƥ��ʤ���

=head1 METHODS

=over 4

=item draw_tree ( FILE_HANDLE )

��ʸ�ڤ���ꤵ�줿 C<FILE_HANDLE> �˽��Ϥ��롥������ά�������ϡ�ɸ
����Ϥ˽��Ϥ���롥

=item sprint_tree ( )

��ʸ�ڤ�ʸ������֤���

=cut
my %POS_MARK = 
    ( '�ü�'     => '*',
      'ư��'     => 'v',
      '���ƻ�'   => 'j',
      'Ƚ���'   => 'c',
      '��ư��'   => 'x',
      '̾��'     => 'n',
      '��ͭ̾��' => 'N',	# ����
      '��̾'     => 'J',	# ����
      '��̾'     => 'C',	# ����
      '�ȿ�̾'   => 'A',	# ����
      '�ؼ���'   => 'd',
      '����'     => 'a',
      '����'     => 'p',
      '��³��'   => 'c',
      'Ϣ�λ�'   => 'm',
      '��ư��'   => '!',
      '��Ƭ��'   => 'p',
      '������'   => 's',
      '̤�����' => '?',
    );

sub _leaf_string {
    my( $obj ) = @_;
    my $string;
    my $utf8_flag = 0;
    for my $mrph ( $obj->mrph() ) {
	my ($midasi, $bunrui, $hinsi) = ($mrph->midasi(), $mrph->bunrui(), $mrph->hinsi());
	if ($utf8_flag or utf8::is_utf8($midasi)) { # euc-jp�ǽ��������Ǹ��utf8_flag��ƤӤ��Ƥ�
	    $utf8_flag = 1 unless $utf8_flag;
	    $midasi = Encode::encode('euc-jp', $midasi);
	    $bunrui = Encode::encode('euc-jp', $bunrui);
	    $hinsi = Encode::encode('euc-jp', $hinsi);
	}
	$string .= $midasi;
	if ( $bunrui =~ /^(?:��ͭ̾��|��̾|��̾)$/ ) {
	    $string .= $POS_MARK{$bunrui};
	} else {
	    $string .= $POS_MARK{$hinsi};
	}
    }
    $utf8_flag ? Encode::decode('euc-jp', $string) : $string;
}

sub _str_real_length {
    my ($str, $utf8_flag) = @_;

    if ($utf8_flag) {
	my $length = 0;
	for my $chr (split(//, $str)) {
	    if ($chr =~ /^[a-zA-Z\*\!\?]$/) {
		$length++; # �ʻ�����Ĺ��1
	    }
	    else {
		$length += 2;
	    }
	}
	return $length;
    }
    else {
	return length($str);
    }
}

sub draw_tree {
    my( $this, $fh ) = @_;

    no strict qw/refs/;
    $fh ||= 'STDOUT';			# ����ʤ��ξ���ɸ����Ϥ��Ѥ��롥
    print $fh $this->sprint_tree();
}

sub sprint_tree {
    my( $this ) = @_;
    my( $i, $j, $para_row, @item );

    my $limit = scalar($this->draw_tree_leaves);
    my( @active_column ) = 0 x $limit--;

    for $i ( 0 .. ( $limit - 1 ) ){
	$para_row = ( ( $this->draw_tree_leaves )[$i]->dpndtype() eq "P" )? 1 : 0;
	for $j ( ( $i + 1 ) .. $limit ){
	    if ( $j < ( $this->draw_tree_leaves )[$i]->parent->id() ) {
		if ( $active_column[$j] == 2 ) {
		    $item[$i][$j] = ( $para_row ? "��" : "��" );
		} elsif ( $active_column[$j] == 1 ) {
		    $item[$i][$j] = ( $para_row ? "��" : "��" );
		} else {
		    $item[$i][$j] = ( $para_row ? "��" : "��" );
		}
	    } elsif ( $j == ( $this->draw_tree_leaves )[$i]->parent->id() ) {
		if ( ( $this->draw_tree_leaves )[$i]->dpndtype() eq "P" ) {
		    $item[$i][$j] = "��";
		} elsif ( ( $this->draw_tree_leaves )[$i]->dpndtype() eq "I" ) {
		    $item[$i][$j] = "��";
		} elsif ( ( $this->draw_tree_leaves )[$i]->dpndtype() eq "A" ) {
		    $item[$i][$j] = "��";
		} else {
		    if ( $active_column[$j] == 2 ) {
			$item[$i][$j] = "��";
		    } elsif ( $active_column[$j] == 1 ) {
			$item[$i][$j] = "��";
		    } else {
			$item[$i][$j] = "��";
		    }
		}
		if ( $active_column[$j] == 2 ) {
		    ;		# ���ǤˣФ��������������Ф��Τޤ�
		} elsif ( $para_row ) {
		    $active_column[$j] = 2;
		} else {
		    $active_column[$j] = 1;
		}
	    } else {
		if ( $active_column[$j] == 2 ) {
		    $item[$i][$j] = "��";
		} elsif ( $active_column[$j] == 1 ) {
		    $item[$i][$j] = "��";
		} else {
		    $item[$i][$j] = "��";
		}
	    }
	}
    }

    my( @line ) = map( &_leaf_string($_), $this->draw_tree_leaves );
    my $utf8_flag = utf8::is_utf8($line[0]) ? 1 : 0 if @line;
    for $i ( 0 .. $limit ){
	for $j ( ( $i + 1 ) .. $limit ){
	    $line[$i] .= $utf8_flag ? Encode::decode('euc-jp', $item[$i][$j]) : $item[$i][$j];
	}
    }
    my $max_length = ( sort { $b <=> $a; } map( &_str_real_length($_, $utf8_flag), @line ) )[0];
    my $buf;
    for $i ( 0 .. $limit ){
	my $diff = $max_length - &_str_real_length($line[$i], $utf8_flag);
	$buf .= ' ' x $diff;
	$buf .= $line[$i] . ($this->draw_tree_leaves)[$i]->pstring . "\n";
    }
    return $buf;
}

=item draw_tree_leaves

�ڹ�¤���դȤʤ륪�֥������ȤΥꥹ�Ȥ��֤��᥽�åɡ�C<KNP::DrawTree> 
���饹��Ѿ����륯�饹���������ɬ�פ����롥

=cut
sub draw_tree_leaves {
    croak "Undefined method is called";
}

=back

=head1 AUTHOR

=over 4

=item
�ڲ� ��̭ <tsuchiya@pine.kuee.kyoto-u.ac.jp>

=back

=cut

1;
__END__
# Local Variables:
# mode: perl
# coding: euc-japan
# use-kuten-for-period: nil
# use-touten-for-comma: nil
# End:
