## ######### PROJECT NAME : ##########
##
## Objet_Lang.pm
##
## ######### PROJECT DESCRIPTION : ###
##
##
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <alex@intellique.com>
##
## Started on  Wed Jun 14 11:48:40 2006 Boutonnet Alexandre
## Last update Mon Aug 25 15:45:36 2008 Boutonnet Alexandre
##
## ###################################
##

use strict;
use warnings;

package Objet_Lang;

use Objet_Conf;
use Objet_Logger;

# Constucteur :

# Fonction de creation de l'objet le langue.
# Cette fonction prend en parametre :
# 1. Le nom du fichier de langue a charger. Le fichier doit etre present dans /etc/storig/lang.
# 2. Une instance de l'objet logger (Optionnel)
# 3. La langue a charger. (Optionnel)
sub new {
    my $OL = {};

    # Stockage du nom de l'objet
    $OL->{OBJNAME} = shift;

    # Recuperation du nom du fichier de langue
    my $file_name = shift;

    # Recuperation de l'objet logger
    $OL->{LOGGER} = shift;

    # Recuperation de la langue.
    my $asked_lang = shift;

    # Definition de la variable de gestion des erreurs
    my $err;

    # Si l'objet logger est absent, je le crée.
    if ( !$OL->{LOGGER} ) {
        ( $err, $OL->{LOGGER} ) = new Objet_Logger();
        $OL->{LOGGER}->debug(
            "$OL->{OBJNAME} : new : $OL->{LOGGER} parametre is missing.");
    }
    unless ( ref( $OL->{LOGGER} ) eq "Objet_Logger" ) {
        ( $err, $OL->{LOGGER} ) = new Objet_Logger();
        $OL->{LOGGER}->debug(
            "$OL->{OBJNAME} : new : $OL->{LOGGER} isn't an Objet_Logger");
    }

    # Test sur le fichier de lang
    if ( !$file_name ) {
        $OL->{LOGGER}
            ->error("Objet_Lang : new : file name parameter is missing");
        return ( 1, "File name parameter is missing" );
    }

    # Je set la langue par defaut à l'anglais
    my $lang       = "en";
    my $found_lang = $lang;

    my $skip_language_detection = 0;

    # Avec ce if je gere le param de forcage de langue..
    if ( defined($asked_lang) ) {
        $found_lang              = $asked_lang;
        $skip_language_detection = 1;
    }

    ### Je cherche la langue utilisee sur la machine. ###

    # Je set le fichier ou aller chercher la langue
    my $sys_lang_file = "/etc/default/locale";
    my $lang_file     = "/etc/storiq/lang/";

    # J'ouvre mon fichier..
    unless ( open( FILE, $sys_lang_file ) && !$skip_language_detection ) {

        # si l'ouverture du fichier chie, j'utilise la langue par defaut
        unless ($skip_language_detection) {
            $OL->{LOGGER}->error(
                "Objet_Lang : new : Unable to Open $sys_lang_file.. Using default language ($lang)"
            );
        }
    }
    else {
        my $tmp_lang;

        # sinon je parse mon fichier
        while (<FILE>) {

            # je recupere ma langue
            if ( $_ =~ m/^\s*LANG=[\s\"]*([a-zA-Z]+)_/ ) {
                $tmp_lang = $1;
                last;
            }
        }
        if ($tmp_lang) { $found_lang = $tmp_lang }
    }

    # Je m'assure que found_lang est en minuscule
    $found_lang =~ tr/[A-Z]/[a-z]/;

    # je tests si le fichier de langue trouve est lisible
    if ( -r $lang_file . $found_lang . "/" . $file_name ) {
        $lang_file .= $found_lang . "/" . $file_name;
    }

    # Sinon je test si le fichier par defaut est lisible
    elsif ( -r $lang_file . $lang . "/" . $file_name ) {
        $lang_file .= $lang . "/" . $file_name;
        $OL->{LOGGER}->warn(
            "Objet_Lang : new : file name not found.. using default one");
    }

    # Sinon je me casse
    else {
        $OL->{LOGGER}->error("Objet_Lang : new : no file found..");
        return ( 1, "No file found" );
    }

    # J'ouvre mon fichier de langue grace a objet conf
    ( $err, $OL->{CONF} ) =
        new Objet_Conf( $lang_file, $OL->{LOGGER}, "=", "#" );
    return ( 1, "Unable to instanciate Objet_Conf" ) if ($err);

    bless($OL);
    return ( 0, $OL );
}

# Fonction de recuperation d'une traduction
# Cette fonction prend en parametre :
# 1. La clef correspondant a la traduction demandee
# 2. Une liste des variables a substituer. Attention, cette liste doit etre
# passee que si le message de traduction contient des champs a substituer !
sub get_msg {
    my $OL = shift;

    # Je recup ma clef
    my $key = shift;

    # Je la teste...
    if ( !defined($key) ) {
        $OL->{LOGGER}
            ->error("Objet_Lang : get_msg : key parameter is missing");
        return ( 1, "The key is missing" );
    }

    # Je recupere les parametres optionnels
    my @param_tab = @_;

    # Je recupere ma reponse en fonction de ma clef
    my ( $error, $reponse ) = $OL->{CONF}->get_value($key);

    # s'il y a une erreur, je la remplace par message d'erreur par defaut.
    if ($error) {
        ( $error, $reponse ) = $OL->{CONF}->get_value("default");
        $OL->{LOGGER}->warn("Objet_Lang : get_msg : default message used");

        # tester si defaut n'existe pas !!!
        if ($error) {
            $OL->{LOGGER}->error(
                "Objet_Lang : get_msg : default message is not found");
            return ( 1, "Default message not found" );
        }
        return ( _sub_in_rep( $OL, $reponse, $key ) );
    }
    else {
        return ( _sub_in_rep( $OL, $reponse, @param_tab ) );
    }

    return ( 1, "An impossible error occured.. :)" );
}

# Fonction de recuperation d'une traduction en fonction d'une section
# Cette fonction prend en parametre :
# 1. La clef correspondant a la traduction demandee
# 2. La section dans laquelle la clef est cherchee
# 3. Une liste des variables a substituer. Attention, cette liste doit etre
# passee que si le message de traduction contient des champs a substituer !
sub get_msg_with_section {
    my $OL = shift;

    # Je recup ma clef
    my $key = shift;

    # Je recup ma section
    my $section = shift;

    # Je test ma clef
    if ( !$key ) {
        $OL->{LOGGER}->error(
            "Objet_Lang : get_msg_with_section : key parameter is missing");
        return ( 1, "Key parameter is missing" );
    }

    # Je test ma section
    if ( !$section ) {
        $OL->{LOGGER}->error(
            "Objet_Lang : get_msg_with_section : section parameter is missing"
        );
        return ( 1, "Section parameter is missing" );
    }

    # Je recupere les parametre optionnels
    my @param_tab = @_;

    # Je recupere ma reponse en fonction de ma clef
    my ( $error, $reponse ) = $OL->{CONF}->get_value( $key, $section );

    # si la reponse est vide, je la remplace par message d'erreur par defaut.
    if ($error) {
        ( $error, $reponse ) = $OL->{CONF}->get_value("default");
        $OL->{LOGGER}->warn(
            "Objet_Lang : get_msg_with_section : default message used $key $section"
        );

        # tester si defaut n'existe pas !!!
        if ($error) {
            $OL->{LOGGER}->error(
                "Objet_Lang : get_msg_with_section : default message is missing"
            );
            return ( 1, "Default message is missing" );
        }
        return ( _sub_in_rep( $OL, $reponse, $key ) );
    }
    else {
        return ( _sub_in_rep( $OL, $reponse, @param_tab ) );
    }

    return ( 1, "An impossible error occured.. :)" );
}

#########################################################################################
####            METHODES PRIVEES
#########################################################################################

sub _sub_in_rep {

#($string, [$str1, $str2, $str3, ...])
# - $string est la chaine de caractere dans laquelle on doit remplacer les balises
# par les variables optionnelles.
# - $str1, $str2, $str3 sont des variables optionnelles qui contiennent des
# string à ajouter dans le message d'erreur..

    my $OL = shift;

    # recuperation de reponse
    my $reponse   = shift;
    my @param_tab = @_;

    # Je compte le nombre de balise que je dois afficher
    my @tmp = ( $reponse =~ /\$\$/g );
    my $nombre = scalar(@tmp);

    # je verifie qu'il y ait bien le meme nombre de champs à remplacer
    if ( $nombre != scalar(@param_tab) ) {
        $OL->{LOGGER}->error(
            "Objet_Lang : _sub_in_rep : incorrect number of parameter for substitution.."
        );
        return ( 1, "Incorrect number of parameter for substitution." );
    }

    # Je remplace ....
    foreach my $remp (@param_tab) {
        $reponse =~ s/\$\$/$remp/;
    }

    # je retourne..
    return ( 0, $reponse );
}

1;
