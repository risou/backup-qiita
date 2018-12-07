use strict;
use warnings;
use utf8;
use Encode;
binmode STDOUT, ':utf8';

use WebService::Qiita::V2;

sub run {
    my ($token, $team) = @_;

    my $client = WebService::Qiita::V2->new;
    $client->{token} = $token;
    $client->{team} = $team if defined($team);

    mine($client);
    stocks($client);
}

sub mine {
    my $client = shift;

    my $page = 1;
    while (1) {
        my $items = $client->get_authenticated_user_items({ page => $page, per_page => 100 });

        extract($client, $items);
        last if (scalar(@$items) < 100);
        $page++;
    }
}

sub stocks {
    my $client = shift;

    my $user = $client->get_authenticated_user;
    my $page = 1;
    while (1) {
        my $items = $client->get_user_stocks($user->{id}, { page => $page, per_page => 100 });

        extract($client, $items);
        last if (scalar(@$items) < 100);
        $page++;
    }
}

sub extract {
    my ($client, $items) = @_;

    my $file_path = 'https://' . $client->{team} . '.qiita.com/files/';
    foreach my $item (@$items) {
        my $title = $item->{title};
        my $contents = $item->{body};

        for my $match ($contents =~ m/${file_path}[\w\-\.]+/g) {
            my $name = substr $match, length($file_path);
            `curl -H "Authorization: Bearer $client->{token}" -L -o images/$name $match`;
        }
        $contents =~ s/${file_path}/..\/images\//g;

        my $file_name = $title . ".md";
        $file_name =~ s/\//\-/g;
        print $file_name, "\n";
        open FILE, "> files/" . $file_name or die $!;
        print FILE "title: " . encode('utf-8', $title), "\n";
        print FILE "url: " . $item->{url}, "\n";
        print FILE "author: " . $item->{user}->{name}, "\n";
        print FILE "----\n";
        print FILE encode('utf-8', $contents);
        close FILE;
    }
}

run(@ARGV);
