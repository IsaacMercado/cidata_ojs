<?php

/**
 * @file theme/revedacyt/RevedacytThemePlugin.php
 *
 * Tema CIDATA / REVEDACYT para OJS 3.5.
 * Tema hijo de "default": hereda plantillas, estilos y opciones del tema base.
 */

namespace APP\plugins\themes\revedacyt;

use PKP\core\PKPSessionGuard;
use PKP\plugins\ThemePlugin;

class RevedacytThemePlugin extends ThemePlugin
{
    /**
     * @copydoc ThemePlugin::isActive()
     *
     * En CLI (sin contexto) el tema debe considerarse activo para que el
     * registro de plugins no falle.
     */
    public function isActive()
    {
        if (PKPSessionGuard::isSessionDisable()) {
            return true;
        }
        return parent::isActive();
    }

    /**
     * Initialize the theme.
     */
    public function init()
    {
        // Hereda del tema default (opciones, estilos y plantillas).
        $this->setParent('defaultthemeplugin');

        // Barra institucional superior.
        $this->addOption('showTopbar', 'FieldOptions', [
            'label' => __('plugins.themes.revedacyt.option.showTopbar.label'),
            'options' => [
                [
                    'value' => true,
                    'label' => __('plugins.themes.revedacyt.option.showTopbar.option'),
                ],
            ],
            'default' => true,
        ]);

        $this->addOption('topbarAddress', 'FieldText', [
            'label' => __('plugins.themes.revedacyt.option.topbarAddress.label'),
            'default' => 'Av. Alberto Carnevali vía La Hechicera, Edificio CIDATA',
        ]);

        $this->addOption('topbarEmail', 'FieldText', [
            'label' => __('plugins.themes.revedacyt.option.topbarEmail.label'),
            'default' => 'cida@mincyt.gob.ve',
        ]);

        $this->addOption('socialInstagram', 'FieldText', [
            'label' => __('plugins.themes.revedacyt.option.socialInstagram.label'),
            'default' => 'https://www.instagram.com/cidata_ve',
        ]);

        $this->addOption('socialYouTube', 'FieldText', [
            'label' => __('plugins.themes.revedacyt.option.socialYouTube.label'),
            'default' => 'https://www.youtube.com/@SocializaCIDATA',
        ]);

        $this->addOption('socialFacebook', 'FieldText', [
            'label' => __('plugins.themes.revedacyt.option.socialFacebook.label'),
            'default' => 'https://www.facebook.com/cidata.ve',
        ]);

        $this->addOption('socialTikTok', 'FieldText', [
            'label' => __('plugins.themes.revedacyt.option.socialTikTok.label'),
            'default' => 'https://www.tiktok.com/@fundacioncidata',
        ]);

        // Texto sobre el hero.
        $this->addOption('heroKicker', 'FieldText', [
            'label' => __('plugins.themes.revedacyt.option.heroKicker.label'),
            'default' => 'CIDATA · Acceso abierto',
        ]);

        // Logos institucionales en el pie.
        $this->addOption('showInstitutionalLogos', 'FieldOptions', [
            'label' => __('plugins.themes.revedacyt.option.showInstitutionalLogos.label'),
            'options' => [
                [
                    'value' => true,
                    'label' => __('plugins.themes.revedacyt.option.showInstitutionalLogos.option'),
                ],
            ],
            'default' => true,
        ]);

        // Estilos del tema (se cargan después de los del tema default).
        // Nombre distinto de "stylesheet" para no reemplazar los estilos base.
        $this->addStyle('cidata', 'styles/index.css');
    }

    /**
     * @copydoc ThemePlugin::getDisplayName()
     */
    public function getDisplayName()
    {
        return __('plugins.themes.revedacyt.name');
    }

    /**
     * @copydoc ThemePlugin::getDescription()
     */
    public function getDescription()
    {
        return __('plugins.themes.revedacyt.description');
    }

    /**
     * @copydoc ThemePlugin::getContextSpecificPluginSettingsFile()
     */
    public function getContextSpecificPluginSettingsFile()
    {
        return $this->getPluginPath() . '/settings.xml';
    }
}
