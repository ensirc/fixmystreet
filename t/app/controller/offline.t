use FixMyStreet::TestMech;
use Path::Tiny;

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'test'
}, sub {
    my $theme_dir = path(FixMyStreet->path_to('web/theme/test'));
    $theme_dir->mkpath;
    my $image_path = path('t/app/controller/sample.jpg');
    $image_path->copy($theme_dir->child('sample.jpg'));
    subtest 'manifest' => sub {
        my $j = $mech->get_ok_json('/.well-known/manifest.webmanifest');
        is $j->{name}, 'FixMyStreet', 'correct name';
        is $j->{theme_color}, '#ffd000', 'correct theme colour';
        is_deeply $j->{icons}[0], {
            type => 'image/jpeg',
            src => '/theme/test/sample.jpg',
            sizes => '133x100'
        }, 'correct icon';
    };
    $theme_dir->remove_tree;
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet'
}, sub {
    subtest '.com manifest' => sub {
        my $j = $mech->get_ok_json('/.well-known/manifest.webmanifest');
        is $j->{related_applications}[0]{platform}, 'play', 'correct app';
        is $j->{icons}[0]{sizes}, '192x192', 'correct fallback size';
    };
};

done_testing();