{**
 * templates/frontend/components/headerHead.tpl
 *
 * Tema CIDATA / REVEDACYT.
 * Añade un favicon de respaldo si la revista no tiene uno configurado.
 *}
<head>
	<meta charset="{$defaultCharset|escape}">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>
		{$pageTitleTranslated|strip_tags}
		{* Add the journal name to the end of page titles *}
		{if $requestedPage|escape|default:"index" != 'index' && $currentContext && $currentContext->getLocalizedName()}
			| {$currentContext->getLocalizedName()}
		{/if}
	</title>

	{load_header context="frontend"}
	{load_stylesheet context="frontend"}

	{assign var="cidataFavicon" value=false}
	{if $currentContext}
		{assign var="cidataFavicon" value=$currentContext->getLocalizedFavicon()}
	{/if}
	{if !$cidataFavicon}
		<link rel="icon" href="{$baseUrl}/plugins/themes/revedacyt/assets/favicon.ico" sizes="any">
		<link rel="icon" type="image/png" sizes="32x32" href="{$baseUrl}/plugins/themes/revedacyt/assets/favicon-32.png">
	{/if}
</head>
