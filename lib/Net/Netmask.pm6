=begin pod

=head1 NAME

Net::Netmask - Parse, manipulate and lookup IP network blocks

=head1 SYNOPSIS

=begin code

use Net::Netmask;

my $net = Net::Netmask.new('192.168.75.8/29');

say $net.desc;        # 192.168.75.8/29 (same as ~$net or $net.Str)
say $net.base;        # 192.168.75.8
say $net.mask;        # 255.255.255.248

say $net.broadcast;   # 192.168.75.15
say $net.hostmask;    # 0.0.0.7

say $net.bits;        # 29
say $net.size;        # 8

if $net.match('192.168.75.10') -> $pos {
    say "$peer is in $net and is at index $pos.";
}

# Enumerate subnet
for $net.enumerate -> $ip {
    say $ip;
}

# Split subnet into smaller blocks
for $net.enumerate(:30bit :nets) -> $addr {
    say $addr;
}

=end code


=head1 DESCRIPTION

C<Net::Netmask> parses and understands IPv4 CIDR blocks. The interface is inspired by the Perl 5 module of the same name.

This module does not have full method parity with it's Perl 5 cousin. Pull requests are welcome.


=head1 CONSTRUCTION

C<Net::Netmask> objects are created with an IP address and mask.

Currently, the following forms are recognized

    # CIDR notation (1 positional arg)
    Net::Netmask.new('192.168.75.8/29');

    # Address and netmask (1 positional arg)
    Net::Netmask.new('192.168.75.8 255.255.255.248')

    # Address and netmask (2 positional args)
    Net::Netmask.new('192.168.75.8', '255.255.255.248')

    # Named arguments
    Net::Netmask.new( :address('192.168.75.8') :netmask('255.255.255.248') );

Using a 'hostmask' (aka, 'wildcard mask') in place of the netmask will also work.

If you create a C<Net::Netmask> object from one of the host addresses in the subnet, it will still work

    my $net = Net::Netmask.new('192.168.75.10/29');
    say ~$net;    # 192.168.75.8/29

IP Addresses are validated against the following subset

    token octet   { (\d+) <?{ $0 <= 255 }>  }
    regex address { <octet> ** 4 % '.'      }
    subset IPv4 of Str where /<address>/;


=head1 METHODS

=head2 address

Returns the first address of the network block, aka the network address.

Synonyms: base, first

=head2 netmask

Returns the subnet mask in dotted-quad notation.

Synonyms: mask

=head2 hostmask

Returns the inverse of the netmask, aka wildcard mask.

=head2 broadcast

Returns the last address of the network block, aka the broadcast address.

Synonyms: last

=head2 bits

Returns the number of bits in the network portion of the netmask, which is the same number that appears at the end of a network written in CIDR notation.

    say Net::Netmask.new('192.168.0.0', '255.255.255.0').bits;   # 24
    say Net::Netmask.new('192.168.0.0', '255.255.255.252').bits; # 30

=head2 size

Returns the number of IP address in the block

    say Net::Netmask.new('192.168.0.0', '255.255.255.0').size;   # 256
    say Net::Netmask.new('192.168.0.0', '255.255.255.252').size; # 4

=head2 match

    method match(IPv4 $ip)

Given a valid IPv4 address, returns a true value if the address is contained within the subnet. That is to say, it will return the addresses index in the subnet.

    my $net = Net::Netmask.new('192.168.0.0/24');
    if $net.match('192.168.0.0') -> $pos {
        say "IP is at index $pos.";
    }

In the above example, C<match> returns C<0 but True>, so even if you are matching on the network address (at position C<0>) it still evaluates as C<True>. If the address is not in the subnet, it will return C<False>.

You could also build a ridumentary blacklist (or whitelist) checker out of an array of C<Net::Netmask> objects.

    my @blacklist = map { Net::Netmask.new($_) },
      < 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 >;

    my $host = '192.168.0.15';
    if ( any @blacklist».match($host) ) {
        say "$host is blacklisted";
    }

=head2 enumerate

    method enumerate(Int :$bit = 32, Bool :$nets)

Returns a lazy list of the IP addresses in that subnet. By default, it enumerates over all the 32-bit subnets (ie. single addresses) in the subnet, but by providing an optional named C<Int> argument C<:bit> , you can split the subnet into smaller blocks

        # Split subnet into /30 blocks
    for $net.enumerate(:30bit) -> $ip {
        say $ip;
    }

Additionally, you can also pass an optional named C<Bool> argument C<:nets>, which will return C<Net::Netmask> objects instead of C<Str>s.

While you can subscript into the list generated by enumerate, it is not recommended for large subnets, because while C<enumerate> produces a lazy list, it will still need to evaluate all previous entries before the subscripted one.

    # Addresses 0..3 were still evaluated
    say "The address at index 4 is $net.enumerate[4]"

Instead you are recommended to use the C<nth> method.

=head2 nth

    method nth($n, Int :$bit = 32, Int :$nets)

This method works similarly to C<enumerate>, except it is optimised for subscripting, which is most noticeable with large ranges

    my $net = Net::Netmask.new('10.0.0.0/8');

    # Instant result
    say "The 10000th address is " ~ $net.nth(10000);

    # Takes several seconds
    say "The 10000th address is " ~ $net.enumerate[10000];

This method will also happily takes a C<Range> as it's argument, but if you want to get any trickier, you will need to provide a container to ensure it is passed as a single argument.

    # Works as expected
    say $net.nth(10000..10010);

    # Too many arguments
    say $net.nth(10000..10010, 20000);

    # Works if in container
    say $net.nth([10000..10010, 20000]);

    # This also works
    my @n = 10000..10010, 20000;
    say $net.nth(@n);

The named arguments C<:bit> and C<:nets> work identically to C<enumerate>

=head2 next

    method next()

Returns a C<Net::Netmask> object of the next block with the same mask.

    my $net = Net::Netmask.new('192.168.0.0/24');
    my $next = $net.next;

    say "$next comes after $net"; # 192.168.1.0/24 comes after 192.168.0.0/24

Alternatively, you can increment your C<Net::Netmask> object to the next block by using the auto-increment operator

    say "This block is $net"; # This block is 192.168.0.0/24
    $net++;
    say "Next block is $net"; # Next block is 192.168.1.0/24

=head2 prev

    method prev()

Just like C<next> but in reverse. Returns a C<Net::Netmask> object of the previous block with the same mask.

    my $net = Net::Netmask.new('192.168.0.1/24');
    my $prev = $net.prev;

    say "$prev comes before $net"; # 192.168.0.0/24 comes before 192.168.1.0/24

Alternatively, you can decrement your C<Net::Netmask> object to the previous block by using the auto-decrement operator

    say "This block is $net"; # This block is 192.168.1.0/24
    $net--;
    say "Next block is $net"; # Previous block is 192.168.0.0/24


=head1 BUGS, LIMITATIONS, and TODO

As mentioned in the description, this module does not have method parity with the Perl 5 module of the same name. I didn't really look at how the other module is implemented, so there's a chance some of my methods might be horribly inefficient. Pull requests are welcome!

As yet I have not written tests... For shame.


=head1 LICENCE

    The Artistic License 2.0

See LICENSE file in the repository for the full license text.


=end pod

class Net::Netmask {

    has Str $.address;
    has Str $.netmask;
    has Int $!start;
    has Int $!end;

    our token cidr    { (\d+) <?{ $0 <=  32 }>  }
    our token octet   { (\d+) <?{ $0 <= 255 }>  }
    our regex address { <octet> ** 4 % '.'     }
    our subset IPv4 of Str where /<address>/;
    our subset CIDR of Str where /<address> '/' <cidr>/;

    multi method new($address, $netmask) {
        self.bless(:$address :$netmask);
    }

    multi method new(CIDR $cidr) {
        my ($address, $bits) = $cidr.split('/');
        my $netmask = ((2 ** $bits - 1) +< (32 - $bits)).&dec2ip;
        self.bless(:$address :$netmask);
    }

    multi method new($network where *.words == 2) {
        self.new(|$network.words)
    }

    multi method new(*@args) {
        #my ($addr, $mask) = @args.flatmap( *.split(/ \s+ | '/' /) );
        fail("Unable to parse network '{ @args }'")
    }

    submethod BUILD(IPv4 :$address, IPv4 :$netmask) {

        $!netmask = $netmask.split('.')[0] < 128
          ?? $netmask.&bitflip !! $netmask;

        $!start = (
            [Z+&] ($address, $!netmask).map(*.split('.'))
        ).join('.').&ip2dec;

        $!address = $!start.&dec2ip;

        $!end = (
            [Z+^] ($!address, self.hostmask).map(*.split('.'))
        ).join('.').&ip2dec;
    }

    sub ip2dec(\i) {
        i.split('.').flatmap({
            ($^a +< 0x18), ($^b +< 0x10), ($^c +< 0x08), $^d
        }).sum;
    }

    sub dec2ip(\d) {
        ( (d +> 0x18, d +> 0x10, d +> 0x08, d) »%» 0x100 ).join('.');
    }

    sub bitflip(\a) {
        ( a.split('.') »+^» 0xFF ).join('.');
    }

    method Str     { "$.base/$.bits";      }
    method gist    { qq[Net::Netmask.new("$.Str")]; }

    method Numeric { $!start; }
    method Int     { $!start; }

    method desc    { self.Str;  }
    method mask    { $.netmask; }

    method hostmask {
        $!netmask.&bitflip;
    }

    method broadcast {
        $!end.&dec2ip;
    }

    method last {
        $.broadcast;
    }

    method base {
        $!address;
    }

    method first {
        $.base;
    }

    method bits {
        $!netmask.split('.').map(*.Int.base: 2).comb('1').elems;
    }

    method size {
        $!end - $!start + 1;
    }

    method enumerate(Int :$bit = 32, Bool :$nets) {
        $bit > 32 and fail('Cannot split network into smaller than /32 blocks');
        my $inc = 2 ** ( 32 - $bit );
        ($!start, * + $inc ... * > $!end - $inc).map(&dec2ip).map(-> $ip {
            $nets ?? self.new( "$ip/$bit" ) !! $ip
        });
    }

    method nth($n, Int :$bit = 32, Bool :$nets) {
        $bit > 32 and fail('Cannot split network into smaller than /32 blocks');
        my $inc = 2 ** ( 32 - $bit ) × 1;
        my @n = $n.flatmap(* × $inc);
        if @n.first( * >= $.size ) -> $i {
            return fail(
                "Index out of range. Is: { $i ÷ $inc }, "
              ~ "should be in 0..{ ($.size ÷ $inc) - 1 }"
            );
        }
        ($!start .. $!end)[@n].map(&dec2ip).map(-> $ip {
            $nets ?? self.new( "$ip/$bit" ) !! $ip
        });
    }

    method match($ip where /<address>/) {
        my $dec = $ip.Str.&ip2dec;
        $!end >= $dec >= $!start ?? ($dec - $!start) but True !! False;
    }

    method next {
        self.new(($!start + $.size).&dec2ip, $.netmask);
    }

    method prev {
        self.new(($!start - $.size).&dec2ip, $.netmask);
    }

    method succ {
        $.next;
    }

    method pred {
        $.prev
    }

}

