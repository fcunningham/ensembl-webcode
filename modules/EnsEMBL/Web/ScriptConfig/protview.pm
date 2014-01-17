package EnsEMBL::Web::ScriptConfig::protview;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw(
    panel_domain            on
    panel_other             on
    panel_variation         on
    show                    plain
    number                  off   
  ));
}
1;