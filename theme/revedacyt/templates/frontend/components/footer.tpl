{**
 * templates/frontend/components/footer.tpl
 *
 * Copyright (c) 2014-2021 Simon Fraser University
 * Copyright (c) 2003-2021 John Willinsky
 * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
 *
 * @brief Common site frontend footer.
 *
 * @uses $isFullWidth bool Should this page be displayed without sidebars? This
 *       represents a page-level override, and doesn't indicate whether or not
 *       sidebars have been configured for thesite.
 *
 * @hook Templates::Common::Sidebar []
 * @hook Templates::Common::Footer::PageFooter []
 *}

	</div><!-- pkp_structure_main -->

	{* Sidebars *}
	{if empty($isFullWidth)}
		{capture assign="sidebarCode"}{call_hook name="Templates::Common::Sidebar"}{/capture}
		{if $sidebarCode}
			<div class="pkp_structure_sidebar left" role="complementary">
				{$sidebarCode}
			</div><!-- pkp_sidebar.left -->
		{/if}
	{/if}
</div><!-- pkp_structure_content -->

<div class="pkp_structure_footer_wrapper" role="contentinfo">
	<a id="pkp_content_footer"></a>

	<div class="cidata-footer">
		{if $activeTheme && $activeTheme->getOption('showInstitutionalLogos')}
		<div class="cidata-footer__institutional">
			<div class="cidata-container">
				<img src="{$baseUrl}/plugins/themes/revedacyt/assets/institutional-logos.png" alt="Ministerio del Poder Popular para Ciencia y Tecnología · CIDATA">
				<div class="cidata-footer__note">
					Fundación Centro de Investigaciones de Astronomía<br>
					y Tecnologías Aplicadas «Francisco J. Duarte»
				</div>
			</div>
		</div>
		{/if}

		{if $pageFooter}
		<div class="cidata-footer__page">
			<div class="cidata-container">{$pageFooter}</div>
		</div>
		{/if}

		<div class="cidata-footer__bar">
			<div class="cidata-container">
				<span class="cidata-footer__copy">© {$smarty.now|date_format:"Y"} {if $currentContext}{$currentContext->getLocalizedName()|escape}{else}REVEDACYT{/if}</span>
				<div class="cidata-footer__links">
					<a href="{url page="about"}">{translate key="about.aboutContext"}</a>
					<a href="{url page="about" op="submissions"}">{translate key="about.submissions"}</a>
					<a href="{url page="about" op="contact"}">{translate key="about.contact"}</a>
				</div>
				{if $activeTheme}
				{assign var="ig" value=$activeTheme->getOption('socialInstagram')}
				{assign var="yt" value=$activeTheme->getOption('socialYouTube')}
				{assign var="fb" value=$activeTheme->getOption('socialFacebook')}
				{assign var="tk" value=$activeTheme->getOption('socialTikTok')}
				{if $ig || $yt || $fb || $tk}
				<div class="cidata-footer__social">
					{if $ig}<a href="{$ig|escape}" target="_blank" rel="noopener" aria-label="Instagram" title="Instagram">IG</a>{/if}
					{if $yt}<a href="{$yt|escape}" target="_blank" rel="noopener" aria-label="YouTube" title="YouTube">YT</a>{/if}
					{if $fb}<a href="{$fb|escape}" target="_blank" rel="noopener" aria-label="Facebook" title="Facebook">FB</a>{/if}
					{if $tk}<a href="{$tk|escape}" target="_blank" rel="noopener" aria-label="TikTok" title="TikTok">TK</a>{/if}
				</div>
				{/if}
				{/if}
				<span class="cidata-footer__credit"><a href="https://pkp.sfu.ca/software/ojs/" target="_blank" rel="noopener">OJS / PKP</a></span>
			</div>
		</div>
	</div>
</div><!-- pkp_structure_footer_wrapper -->

</div><!-- pkp_structure_page -->

{load_script context="frontend"}

{call_hook name="Templates::Common::Footer::PageFooter"}
</body>
</html>
