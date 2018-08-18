#!/usr/bin/env perl

use strict;
use warnings;
use feature qw(:all);

use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types);


my @items;

open my $fh, '-|', 'psql -h localhost -U pgbouncer -p 6432 -AqtXc "SHOW help" 2>&1'
    or die "Couldn't open psql to pgbouncer: $!";

while (my $line = <$fh>) {
    next unless $line =~ m{SHOW\s+(\S+)}x;
    push @items, map{lc} split(/\|/, $1);
}

close $fh;

my $dbh=DBI->connect('dbi:Pg:dbname=pgbouncer;host=/tmp;port=6432','pgbouncer','')
    or die "Couldn't connect to pgbouncer: $!";

foreach my $item(sort @items) {
    my $sth=$dbh->prepare("SHOW $item");
    $sth->execute;
    my $name=$sth->{NAME_lc_hash};
    my $type=$sth->{pg_type};
    my @cols = map { join(" ", $dbh->quote_identifier($_), $type->[$name->{$_}]) } sort { $name->{$a} <=> $name->{$b} } keys %{$name};
    next unless $#cols > 0;
    say <<~EOT
    CREATE VIEW pgbouncer.$item AS
    SELECT * FROM dblink('pgbouncer', 'SHOW $item') AS _(
        @{[ join(",\n    ", @cols) ]}
    );
    EOT
}
