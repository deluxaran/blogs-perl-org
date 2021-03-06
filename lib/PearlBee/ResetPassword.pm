package ResetPassword;

use strict;
use warnings;

use Dancer2;
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::reCAPTCHA;

use PearlBee::Helpers::Util;

use PearlBee::Password;

use DateTime;


get '/activation' => sub {

    info "\n\n~~~~~~~~~~~~ activation link ~~~~~~~~~~~~~~~~~~~~~~~~\n\n";
    my $token = params->{'token'};

    my $user_reset_token = resultset('User')->search( {activation_key => $token} )->first();

    if ($user_reset_token) {
        template 'set-password' => {show_input => 1,token      => $token,}, {layout => 'admin'};
    }
    else {
        session error => 'Your activation token is invalid, please try the forgot password option again.';

        template 'login';
    }
};

any ['post', 'get'] => '/set-password' => sub {
    my $params = params;

    if ( $params->{'token'} ) {

        my $al = resultset('User')->search( {activation_key => $params->{'token'}} )->first();

        if ( defined($al) ) {

            # post request
            if ( $params->{'password'} ) {

                # passwords must be typed in twice and they were the same
                if ( $params->{'password'} eq $params->{'rep_password'} ) {
                    my $password = crypt( $params->{'password'}, $al->salt );
                    
                    if ( $al->update( {password => $password->{hash}, activation_key => ''} ) ) {
                        my $user_obj->{is_admin} = $al->is_admin;
                        $user_obj->{role}     = $al->role;
                        $user_obj->{id}       = $al->id;
                        $user_obj->{username} = $al->username;

                        session user    => $user_obj;
                        session user_id => $al->id;

                        session success => 'Your password was sucessfuly changed';
                        redirect('/dashboard');
                    }
                }
                else {
                    session error                 => 'Your inputed passwords do not match';
                    template 'set-password' => {show_input => 1,token      => $params->{'token'},}, {layout => 'admin'};
                }
            }
        }
    }
    #get request
    else {
        template 'set-password' => {show_input => 1,token      => $params->{'token'},}, {layout => 'admin'};
    }
};


any ['get', 'post'] => '/forgot-password' => sub {
    my $params = params;

    #it was a post request
    if ( $params->{email} ) {

        my $secret = param('g-recaptcha-response');
        my $result = recaptcha_verify($secret);
        if ( $result->{success} || $ENV{CAPTCHA_BYPASS} ) {

            my $user = resultset('User')->search( {email => $params->{email}} )->first;

            if ($user) {
                my $date             = DateTime->now();
                my $activation_token = generate_hash( $params->{email} . $date );

                my $token = $activation_token->{hash};

                if ($token) {
                    if ( $user->status ne 'suspended' ) {
                        $user->update( {activation_key => $token} );
                        Email::Template->send(
                            config->{email_templates} . 'forgot-password.tt',
                            {   From    => config->{default_email_sender},
                                To      => $params->{email},
                                Subject => 'Reset password link on blog.cluj.pm',

                                tt_vars => {
                                    name      => $user->name,
                                    app_url   => config->{app_url},
                                    token     => "/activation?token=$token",
                                    blog_name => session('blog_name'),
                                    signature => config->{email_signature}
                                },
                            }
                        ) or error "Could not send the email";

                        session success => 'You have successfully reset you password! Please check your inbox!';
                        template 'forgot-password', {show_input => 0}, {layout => 'admin'};
                    }
                    else {
                        session error => 'Your account is suspended!';
                        template 'forgot-password', {show_input => 0}, {layout => 'admin'};
                    }
                }

                # no user with this email
                else {
                    session warning => 'There is no user with this email address:' . $params->{'email'};
                    template 'forgot-password', {show_input => 1}, {layout => 'admin'};
                }
            }

            # captcha incorrect
            else {
                session error => 'Incorrect captcha';
                template 'forgot-password', {
                    show_input => 1,
                    recaptcha => recaptcha_display(),
                }, {layout => 'admin'};
            }
        }
    }

    # it was a get request
    else {
        template 'forgot-password', {
            show_input => 1,
            recaptcha => recaptcha_display(),
        }, {layout => 'admin'};
    }

};

true;
