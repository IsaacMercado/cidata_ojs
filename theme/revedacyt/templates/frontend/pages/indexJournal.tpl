{**
 * templates/frontend/pages/indexJournal.tpl
 *
 * Tema CIDATA / REVEDACYT — portada nocturna.
 *
 * @uses $currentJournal Journal
 * @uses $journalDescription string
 * @uses $homepageImage object
 * @uses $additionalHomeContent string
 * @uses $announcements array
 * @uses $numAnnouncementsHomepage int
 * @uses $issue Issue
 *
 * @hook Templates::Index::journal []
 *}
{include file="frontend/components/header.tpl" pageTitleTranslated=$currentJournal->getLocalizedName()}

<div class="page_index_journal">

	{call_hook name="Templates::Index::journal"}

	{* Hero *}
	<section class="cidata-hero"{if $homepageImage} style="--cidata-hero-image:url('{$publicFilesDir}/{$homepageImage.uploadName|escape:"url"}')"{/if}>
		<div class="cidata-container cidata-hero__inner">
			{if $activeTheme && $activeTheme->getOption('heroKicker')}
				<div class="cidata-kicker">{$activeTheme->getOption('heroKicker')|escape}</div>
			{/if}
			<h1 class="cidata-hero__title">{$currentJournal->getLocalizedName()|escape}</h1>
			{if $journalDescription}
				<p class="cidata-hero__desc">{$journalDescription|strip_tags|truncate:360:"…":true|escape}</p>
			{/if}
			<div class="cidata-chips">
				{if $issue}
					<span class="cidata-chip cidata-chip--gold">{$issue->getIssueIdentification()|escape}</span>
				{/if}
				{assign var="cidataIssn" value=$currentJournal->getData('onlineIssn')}
				{if !$cidataIssn}
					{assign var="cidataIssn" value=$currentJournal->getData('printIssn')}
				{/if}
				{if $cidataIssn}
					<span class="cidata-chip">ISSN {$cidataIssn|escape}</span>
				{/if}
				<span class="cidata-chip">{translate key="plugins.themes.revedacyt.hero.openAccess"}</span>
			</div>
			<div class="cidata-hero__actions">
				<a class="cidata-btn cidata-btn--primary" href="{url page="about" op="submissions"}">
					{translate key="plugins.themes.revedacyt.hero.submit"}
				</a>
				{if $issue}
					<a class="cidata-btn cidata-btn--ghost" href="{url page="issue" op="view" path=$issue->getBestIssueId()}">
						{translate key="journal.currentIssue"}
					</a>
				{else}
					<a class="cidata-btn cidata-btn--ghost" href="{url page="issue" op="archive"}">
						{translate key="journal.viewAllIssues"}
					</a>
				{/if}
			</div>
		</div>
	</section>

	{if $highlights->count()}
		{include file="frontend/components/highlights.tpl" highlights=$highlights}
	{/if}

	{* Sobre la revista + convocatoria *}
	<section class="cidata-about">
		<div class="cidata-about__grid{if !$journalDescription} cidata-about__grid--single{/if}">
			{if $journalDescription}
				<div>
					<h2 class="cidata-section-title">{translate key="about.aboutContext"}</h2>
					<div class="cidata-prose">{$journalDescription}</div>
					<a class="cidata-link" href="{url page="about"}">{translate key="plugins.themes.revedacyt.about.more"} →</a>
				</div>
			{/if}
			<aside class="cidata-callout">
				<div class="cidata-kicker">{translate key="plugins.themes.revedacyt.callout.kicker"}</div>
				<h3>{translate key="plugins.themes.revedacyt.callout.title"}</h3>
				<p>{translate key="plugins.themes.revedacyt.callout.text"}</p>
				<a class="cidata-btn cidata-btn--primary cidata-btn--small" href="{url page="about" op="submissions"}">
					{translate key="plugins.themes.revedacyt.hero.submit"}
				</a>
			</aside>
		</div>
	</section>

	{* Número actual *}
	{if $issue}
		<section class="cidata-current">
			<div class="cidata-section-head">
				<h2 class="cidata-section-title">{translate key="journal.currentIssue"}</h2>
				<a class="cidata-link" href="{url page="issue" op="archive"}">{translate key="journal.viewAllIssues"} →</a>
			</div>
			<div class="cidata-current__box">
				<div class="cidata-current__meta">
					<div class="cidata-kicker">{translate key="plugins.themes.revedacyt.current.kicker"}</div>
					<h3>{$issue->getIssueIdentification()|escape}</h3>
				</div>
				{include file="frontend/objects/issue_toc.tpl" heading="h3"}
			</div>
		</section>
	{/if}

	{include file="frontend/objects/announcements_list.tpl" numAnnouncements=$numAnnouncementsHomepage}

	{if $additionalHomeContent}
		<section class="cidata-additional">
			{$additionalHomeContent}
		</section>
	{/if}
</div><!-- .page_index_journal -->

{include file="frontend/components/footer.tpl"}
