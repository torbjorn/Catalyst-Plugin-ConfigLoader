package Catalyst::Plugin::ConfigLoader::CLSource;

use Moo;
extends "Config::Loader::Source::Profile::Default";

with "Config::Loader::SourceRole::FileLocalSuffix";
with "Config::Loader::SourceRole::FileFromEnv";

1;
