fx_version 'cerulean'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
game 'gta5'

name 'ps-mdt'
author "Project Sloth Development Team"
description 'Project Sloth MDT'
version '3.1.0'

ui_page 'web/dist/index.html'

dependencies {
  'ps_lib',
  'oxmysql',
  'ox_lib'
}

shared_scripts {
  'config.lua',
  '@ox_lib/init.lua'
}

client_script {
  'client/**.lua',
  'modules/**/client/**/*.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/module_loader.lua', -- Must be loaded first to create the MDT global
  'server/table_map.lua',
  'server/auth.lua',
  'server/cache.lua',
  'server/cameras.lua',
  'server/commands.lua',
  'server/events.lua',
  'server/fivemanage.lua',
  'server/functions.lua',
  'server/main.lua',
  'server/backend/**.lua',
  'modules/**/server/**/*.lua',
}

files {
  'web/dist/index.html',
  'web/dist/**/*',
  'modules/**/*.json',
  -- Module UI bundles must be explicitly included in this resource's file
  -- pack. Nested module fxmanifest files are not loaded as separate resources.
  'modules/**/web/dist/*.js',
  'modules/**/web/dist/**/*.js',
  'modules/**/web/dist/**/*.css',
  'modules/**/web/dist/**/*',
}

exports {
  'RegisterModule'
}

data_file 'DLC_ITYP_REQUEST' 'stream/ps-mdt.ytyp'

-- Server convars (set in server.cfg):
-- set ps_mdt_fivemanage_key_images "YOUR_FIVEMANAGE_IMAGES_API_KEY"
-- set ps_mdt_fivemanage_key_logs   "YOUR_FIVEMANAGE_LOGS_API_KEY"
convar_category 'PS-MDT' {
  'Settings for ps-mdt resource',
  {
    { 'FiveManage Images API Key', 'ps_mdt_fivemanage_key_images', 'CV_STRING', '' },
    { 'FiveManage Logs API Key',   'ps_mdt_fivemanage_key_logs',   'CV_STRING', '' },
  }
}
