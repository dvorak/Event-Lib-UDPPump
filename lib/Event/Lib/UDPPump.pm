package Event::Lib::UDPPump;

use 5.008005;
use strict;
use warnings;

use Event::Lib;
use Exporter 'import';

## no critic (ProhibitAutomaticExportation)

our @EXPORT = qw(
  udppump_new
);

## use critic

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Event::Lib::UDPPump', $VERSION);

1;
__END__

=head1 NAME

Event::Lib::UDPPump - L<Event::Lib> event type for high performance UDP
applications.


=head1 SYNOPSIS

  use Event::Lib::UDPPump;
  use IO::Socket::INET;

  my $numchildren = 10;

  my $s = IO::Socket::INET->new(Proto => 'udp', 
                                LocalPort => 5000);

  fork() foreach (1..($numchildren - 1));

  my $pump = udppump_new($s, \&callback, @args);
  $pump->add();
  event_mainloop();

  sub callback {
    my ($results_href, @args) = @_;
    # Process results here.
  }

=head1 DESCRIPTION

This module is intended for people writing high performance UDP
applications.  It is an extension of the L<Event::Lib> module, and can
provide better performance in several circumstances.

When a UDPPump event is registered for a UDP socket, a pthreads thread
is created in the background.  All this thread does is block in
C<recvfrom> waiting for a packet to be received on the socket.  When
that happens, it will then pass a packet over to the main thread which
will call the callback you have registered.  This will be more
efficent specifically in the case when you have several processes or
threads all processing data on the same UDP port.  This avoids the
problem with multiple processes all blocking in select (or poll, etc)
waiting for traffic on the same socket, and then all waiting up and
trying to read from the socket at the same time when new data arrives. 

This can make it easier to implement daemons where each
request may require significant processing.  This is because while
your callback is running, the recvfrom thread will be blocking waiting
for you to complete.  This means that you can run a number of child
processes as workers, and as long as you have a few of them waiting in
C<recvfrom> then response times will not suffer.

The other primary benefit is that it can allow you to take advantage
of multi-processor/multi-core servers without having to resort to
using threads.  This is the primary reason that this module was
implemented.

=head1 SUBROUTINES/METHODS

=head2 udppump_new($socket, $callback, [@args])

C<$socket> should be a UDP socket.

C<$callback> should be a code reference.  When a packet is received it
will be called with a hash reference as it's first parameter, and
C<@args> as the rest of the parameters, if C<@args> is provided.  

The hash reference will have the following keys:

=over

=item from

This is a packed C<sockaddr_in> that specifies where the packet was
received from.  You can use the C<unpack_sockaddr_in> function in
L<Socket> to unpack this.

=item buffer

This will be the body of the packet received.

=item len

This is the length of the packet received.  It is actually the return
value of recvfrom, so it will be -1 if an error occured.

=item errno

This is the value of C<errno> after recvfrom returns.  This is
probably only useful if C<len> indicates there was an error.

=back

=head2 $event->add()

This will do all the setup work for the UDPPump.  This includes
starting the backgroun thread, and registering some underlying
L<Event::Lib> events for the notification.

=head2 $event->fh()

Returns the file handle associated with the UDPPump event.

=head1 CAVEATS

I can't think of any reason this module wouldn't work just fine on any
type of datagram socket.  In fact, I imagine it'll work great on
anything that recvfrom works on.

There is no way to remove a UDPPump event once it's created.  This
isn't implemented because I didn't care to get into the hairy mess
that is required with thread cancellation, and I expect this will be
used mostly in server applications where the socket is created at
startup and only destroyed on exit.  If you really need to be able to
delete events, it'd probably not be too horrible to implement.

This has only been tested on Solaris 10.  If it doesn't work for you
on another platform, I'm willing to take patches or reasonably helpful
error reports.

=head1 EXPORT

The C<udppump_new> function is exported by default.

=head1 DEPENDENCIES

This module requires the excellent L<Event::Lib> module.

=head1 AUTHOR

Clayton O'Neill, E<lt>udppump.20.coneill@xoxy.netE<gt>

The above email address is a spamgourmet (http://www.spamgourmet.com)
email address.  It will stop working after it receives 20 pieces of
mail.  Given how badly CPAN authors get spammed, that will probably be
pretty quickly.  I'd recommend changing the C<udppump> part above to
anything else when sending me email.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2006 by Clayton O'Neill

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut
