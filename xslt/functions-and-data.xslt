<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xlink="http://www.w3.org/1999/xlink"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:doc="http://www.pnp-software.com/XSLTdoc"
xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:functx="http://www.functx.com" xmlns:opfun="http://data.europa.eu/p27/ted-xml-data-converter"
xmlns:ted="http://publications.europa.eu/resource/schema/ted/R2.0.9/publication"
xmlns:ted-1="http://formex.publications.europa.eu/ted/schema/export/R2.0.9.S01.E01"
xmlns:ted-2="ted/R2.0.9.S02/publication"
xmlns:n2016-1="ted/2016/nuts"
xmlns:n2016="http://publications.europa.eu/resource/schema/ted/2016/nuts" xmlns:n2021="http://publications.europa.eu/resource/schema/ted/2021/nuts"
xmlns:pin="urn:oasis:names:specification:ubl:schema:xsd:PriorInformationNotice-2" xmlns:cn="urn:oasis:names:specification:ubl:schema:xsd:ContractNotice-2" xmlns:can="urn:oasis:names:specification:ubl:schema:xsd:ContractAwardNotice-2"
xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2" xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2" xmlns:ext="urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2"
xmlns:efbc="http://data.europa.eu/p27/eforms-ubl-extension-basic-components/1" xmlns:efac="http://data.europa.eu/p27/eforms-ubl-extension-aggregate-components/1" xmlns:efext="http://data.europa.eu/p27/eforms-ubl-extensions/1"
xmlns:ccts="urn:un:unece:uncefact:documentation:2" xmlns:gc="http://docs.oasis-open.org/codelist/ns/genericode/1.0/"
xmlns:uuid="http://www.uuid.org"
xmlns:math="http://exslt.org/math"
exclude-result-prefixes="xlink xs xsi fn functx doc opfun ted ted-1 ted-2 gc n2016-1 n2016 n2021 pin cn can ccts ext" >
<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

<!-- include FunctX XSLT Function Library -->
<xsl:include href="lib/functx-1.0.1-doc.xsl"/>

<!-- default SDK version -->
<xsl:variable name="sdk-version-default" select="'eforms-sdk-1.7'"/>

<!-- application parameters -->
<xsl:param name="showwarnings" select="1" as="xs:integer"/>
<xsl:param name="includewarnings" select="1" as="xs:integer"/>
<xsl:param name="includecomments" select="1" as="xs:integer"/>

<!-- external conversion parameters -->
<!-- Value for BT-701 Notice Identifier -->
<!-- orig code 
<xsl:param name="notice-identifier" select="tokenize(base-uri(.), '/')[last()]" as="xs:string"/>
end orig code -->
<!-- dfo change start -->
<xsl:param name="notice-identifier" select="substring-before(tokenize(base-uri(.), '/')[last()], '.')" as="xs:string"/>
<!-- dfo change end -->

<!-- Value for BT-04 Procedure Identifier -->
<xsl:param name="procedure-identifier" as="xs:string">
	<xsl:choose>
		<xsl:when test="//COMPLEMENTARY_INFO/NO_DOC_EXT"><xsl:value-of select="//COMPLEMENTARY_INFO/NO_DOC_EXT"/></xsl:when>
		<xsl:otherwise><xsl:value-of select="$notice-identifier"/></xsl:otherwise>		
	</xsl:choose>
</xsl:param>
<!-- Value for SDK version -->
<xsl:param name="sdk-version" select="$sdk-version-default" as="xs:string"/>

<!-- MAPPING FILES -->

<xsl:variable name="eforms-notice-subtypes" select="fn:document('eforms-notice-subtypes.xml')"/>
<xsl:variable name="mappings" select="fn:document('other-mappings.xml')"/>
<xsl:variable name="translations" select="fn:document('translations.xml')"/>
<xsl:variable name="country-codes-map" select="fn:document('countries-map.xml')"/>
<xsl:variable name="language-codes-map" select="fn:document('languages-map.xml')"/>


<!-- #### GLOBAL VARIABLES #### -->

<xsl:variable name="newline" select="'&#10;'"/>
<xsl:variable name="tab" select="'&#09;'"/>

<xsl:variable name="source-document" select="fn:base-uri()"/>

<!-- Apart from <NOTICE_UUID>, all direct children of FORM_SECTION have the same element name / form type -->
<!-- Variable ted-form-elements holds all the form elements (in alternate languages) -->
<xsl:variable name="ted-form-elements" select="/*/*:FORM_SECTION/*[@CATEGORY]"/>
<!-- Variable ted-form-main-element holds the first form element that has @CATEGORY='ORIGINAL'. This is the TED form element which is processed -->
<xsl:variable name="ted-form-main-element" select="/*/*:FORM_SECTION/*[@CATEGORY='ORIGINAL'][1]"/>
<!-- Variable ted-form-additional-elements holds the form elements that are not the main form element -->
<xsl:variable name="ted-form-additional-elements" select="/*/*:FORM_SECTION/*[@CATEGORY][not(@CATEGORY='ORIGINAL' and not(preceding-sibling::*[@CATEGORY='ORIGINAL']))]"/>
<!-- Variable ted-form-elements-names holds a list of unique element names of the ted form elements -->
<xsl:variable name="ted-form-elements-names" select="fn:distinct-values($ted-form-elements/fn:local-name())"/>
<!-- Variable ted-form-element-name holds the element name of the main form element. -->
<xsl:variable name="ted-form-element-name" select="$ted-form-main-element/fn:local-name()"/> <!-- F06_2014 or CONTRACT_DEFENCE or MOVE or OTH_NOT or ... -->
<!-- Variable ted-form-name holds the name of the main form element as held in the @FORM attribute -->
<xsl:variable name="ted-form-name" select="$ted-form-main-element/fn:string(@FORM)"/><!-- F06 or 17 or T02 or ... -->
<!-- Variable ted-form-element-xpath holds the XPath with positional predicates of the main form element -->
<xsl:variable name="ted-form-element-xpath" select="functx:path-to-node-with-pos($ted-form-main-element)"/>

<!-- Variable ted-form-notice-type holds the value of the @TYPE attribute of the NOTICE element -->

<!--orig code
<xsl:variable name="ted-form-notice-type" select="$ted-form-main-element/fn:string(*:NOTICE/@TYPE)"/> end orig code --><!-- '' or PRI_ONLY or AWARD_CONTRACT ... -->
<!-- dfo juks start -->
<xsl:variable name="ted-form-notice-type">
<xsl:choose>
<xsl:when test="$ted-form-main-element/fn:string(*:NOTICE/@TYPE)"><xsl:value-of select="$ted-form-main-element/fn:string(*:NOTICE/@TYPE)"/></xsl:when>
<xsl:otherwise><xsl:value-of select="$ted-form-main-element/fn:string(*:NOTICE/@SECTOR)"/></xsl:otherwise>
</xsl:choose>
</xsl:variable>

<!-- dfo juks end -->


<!-- Variable document-code holds the value of the @TYPE attribute of the NOTICE element -->
<xsl:variable name="document-code" select="/*/*:CODED_DATA_SECTION/*:CODIF_DATA/*:TD_DOCUMENT_TYPE/fn:string(@CODE)"/><!-- 0 or 6 or A or H ... -->
<!-- Variable ted-form-first-language holds the value of the @LG attribute of the first form element with @CATEGORY='ORIGINAL' -->
<xsl:variable name="ted-form-first-language" select="$ted-form-main-element/fn:string(@LG)"/>
<!-- Variable ted-form-additional-languages holds the values of the @LG attribute of the remaining form elements -->
<xsl:variable name="ted-form-additional-languages" select="$ted-form-additional-elements/fn:string(@LG)"/>


<!-- Variable eforms-first-language holds the eForms three-letter code for the first language -->
<xsl:variable name="eforms-first-language" select="opfun:get-eforms-language($ted-form-first-language)"/>

<!-- Variable legal-basis holds the value of the @VALUE attribute of the element LEGAL_BASIS, if it exists. If element LEGAL_BASIS does not exist, it holds the value "OTHER" -->
<xsl:variable name="legal-basis">
	<xsl:choose>
		<xsl:when test="$ted-form-main-element/*:LEGAL_BASIS"><xsl:value-of select="$ted-form-main-element/*:LEGAL_BASIS/@VALUE"/></xsl:when>
		<xsl:otherwise><xsl:text>OTHER</xsl:text></xsl:otherwise>
	</xsl:choose>
</xsl:variable>

<!-- Variable directive holds the value of the @VALUE attribute of the element DIRECTIVE, if it exists. Othewise it holds the empty string -->
<xsl:variable name="directive" select="fn:string(/*/*:CODED_DATA_SECTION/*:CODIF_DATA/*:DIRECTIVE/@VALUE)"/>

<!-- Variable eforms-notice-subtype holds the computed eForms notice subtype value -->
<xsl:variable name="eforms-notice-subtype">
	<xsl:value-of select="opfun:get-eforms-notice-subtype($ted-form-element-name, $ted-form-name, $ted-form-notice-type, $legal-basis, $directive, $document-code)"/>
</xsl:variable>

<!-- Variable eforms-document-type holds the computed Document Type of the notice being converted -->
<xsl:variable name="eforms-document-type">
	<xsl:value-of select="$eforms-notice-subtypes//notice-subtype[id=$eforms-notice-subtype]/fn:string(document-type-id)"/>
</xsl:variable>

<!-- variable eforms-form-type holds the eforms form type -->
<xsl:variable name="eforms-form-type" select="$eforms-notice-subtypes//notice-subtype[id=$eforms-notice-subtype]/fn:string(form-type)"/>

<!-- variable eforms-notice-type holds the eforms notice type -->
<xsl:variable name="eforms-notice-type" select="$eforms-notice-subtypes//notice-subtype[id=$eforms-notice-subtype]/fn:string(notice-type)"/>

<!-- variable eforms-element-name holds the name of the root element -->
<xsl:variable name="eforms-element-name" select="$mappings//form-types/mapping[abbreviation=$eforms-document-type]/fn:string(element-name)"/>

<!-- variable eforms-element-name holds the namespace of the root element -->
<xsl:variable name="eforms-xmlns" select="$mappings//form-types/mapping[abbreviation=$eforms-document-type]/fn:string(xmlns)"/>

<!-- Variable number-of-lots holds the number of Lots (element OBJECT_DESCR) of the notice being converted -->
<xsl:variable name="number-of-lots" select="$ted-form-main-element/*:OBJECT_CONTRACT/fn:count(*:OBJECT_DESCR)"/>

<!-- Variable lot-numbers-map holds a mapping of the TED XML Lots (OBJECT_DESCR XPath) to the calculated eForms Purpose Lot Identifier (BT-137) -->
<xsl:variable name="lot-numbers-map">
	<xsl:variable name="count-lots" select="fn:count($ted-form-main-element/*:OBJECT_CONTRACT/*:OBJECT_DESCR)"/>
	<!-- eForms subtypes 1 to 9 are Planning type notices, and use Parts, not Lots, and the BT-137 value uses "PAR-" and not "LOT-". -->
	<xsl:variable name="lot-prefix">
		<xsl:choose>
			<xsl:when test="$eforms-notice-subtype = ('4', '5', '6', 'E2')">
				<xsl:value-of select="'PAR-'"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="'LOT-'"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<lots>
		<xsl:for-each select="$ted-form-main-element/*:OBJECT_CONTRACT/*:OBJECT_DESCR">
			<lot>
				<xsl:variable name="lot-no"><xsl:value-of select="*:LOT_NO"/></xsl:variable>
				<xsl:variable name="lot-no-is-convertible" select="(($lot-no eq '') or (fn:matches($lot-no, '^[1-9][0-9]{0,3}$')))"/>
				<path><xsl:value-of select="functx:path-to-node-with-pos(.)"/></path>
				<lot-no><xsl:value-of select="$lot-no"/></lot-no>
				<xsl:if test="$lot-no-is-convertible"><is-convertible/></xsl:if>
				<lot-id>
					<xsl:choose>
						<!-- When LOT_NO exists -->
						<xsl:when test="$lot-no">
							<xsl:choose>
								<!-- LOT_NO is a positive integer between 1 and 9999 -->
								<xsl:when test="$lot-no-is-convertible">
									<xsl:value-of select="fn:concat($lot-prefix, functx:pad-integer-to-length(*:LOT_NO, 4))"/>
								</xsl:when>
								<xsl:otherwise>
									<xsl:value-of select="fn:concat($lot-prefix, *:LOT_NO)"/>
								</xsl:otherwise>
							</xsl:choose>
						</xsl:when>
						<!-- When LOT_NO does not exist -->
						<xsl:otherwise>
							<xsl:choose>
								<!-- This is the only Lot in the notice -->
								<xsl:when test="$count-lots = 1">
									<!-- use identifier LOT-0000 or PAR-0000 -->
									<xsl:value-of select="fn:concat($lot-prefix, '0000')"/>
								</xsl:when>
								<xsl:otherwise>
									<!-- not tested, no examples found -->
									<!-- There is more than one Lot in the notice, eForms Lot identifier is derived from the position -->
									<xsl:value-of select="fn:concat($lot-prefix, functx:pad-integer-to-length((fn:count(./preceding-sibling::*:OBJECT_DESCR) + 1), 4))"/>
								</xsl:otherwise>
							</xsl:choose>
						</xsl:otherwise>
					</xsl:choose>
				</lot-id>
			</lot>
		</xsl:for-each>
	</lots>
</xsl:variable>

<!-- #### GLOBAL FUNCTIONS #### -->

<!-- Function opfun:get-eforms-language converts a language code from TED two-letter format to eForms three-letter format -->
<xsl:function name="opfun:get-eforms-language" as="xs:string">
	<!-- function to get eForms language code from given TED language code, e.g. "DA" to "DAN" -->
	<xsl:param name="ted-language" as="xs:string"/>
	<xsl:variable name="mapped-language" select="$language-codes-map//language[ted eq $ted-language]/fn:string(eforms)"/>
	<xsl:value-of select="if ($mapped-language) then $mapped-language else 'UNKNOWN-LANGUAGE'"/>
</xsl:function>

<xsl:function name="opfun:get-eforms-country" as="xs:string">
	<!-- function to get eForms country code from given TED country code, e.g. "BG" to "BGR" -->
	<xsl:param name="ted-country" as="xs:string"/>
	<xsl:variable name="mapped-country" select="$country-codes-map//country[ted eq $ted-country]/fn:string(eforms)"/>
	<xsl:value-of select="if ($mapped-country) then $mapped-country else 'UNKNOWN-COUNTRY'"/>
</xsl:function>

<!-- Function opfun:get-valid-nuts-codes filters a list of NUTS codes to those of more than 4 characters -->
<xsl:function name="opfun:get-valid-nuts-codes" as="xs:string*">
	<!-- function to get eForms language code from given TED language code, e.g. "DA" to "DAN" -->
	<xsl:param name="nuts-codes" as="xs:string*"/>
		<xsl:for-each select="$nuts-codes">
			<xsl:choose>
				<xsl:when test="opfun:is-valid-nuts-code(.)"><xsl:value-of select="."/></xsl:when>
			</xsl:choose>
		</xsl:for-each>
</xsl:function>

<!-- Function opfun:is-valid-nut-code returns true if the given string is a valid NUTS code (string length > 4) -->
<xsl:function name="opfun:is-valid-nuts-code" as="xs:boolean">
	<xsl:param name="nuts-code" as="xs:string"/>
	<xsl:sequence select="fn:string-length($nuts-code) &gt; 4"/>
</xsl:function>

<!-- FORM SUBTYPE -->

<!-- Function opfun:get-eforms-notice-subtype computes the eForms notice subtype, using information from the TED notice -->
<xsl:function name="opfun:get-eforms-notice-subtype" as="xs:string">
	<xsl:param name="ted-form-element"/>
	<xsl:param name="ted-form-name"/>
	<xsl:param name="ted-form-notice-type"/>
	<xsl:param name="legal-basis"/><!-- could be value 'ANY' -->
	<xsl:param name="directive"/><!-- could be value 'ANY' -->
	<xsl:param name="ted-form-document-code"/>
	<xsl:variable name="notice-mapping-file" select="fn:document('notice-type-mapping.xml')"/>
		
	
	<!-- get rows from notice-type-mapping.xml with values matching the given parameters -->
	<!-- dfo modified..add or eq ANY to sevral params  -->
	<xsl:variable name="mapping-row" select="$notice-mapping-file/mapping/row[(form-element eq $ted-form-element) or (form-element eq 'ANY')][(form-number eq $ted-form-name) or (form-number eq 'ANY')][(notice-type eq $ted-form-notice-type) or (notice-type eq 'ANY')][(legal-basis eq $legal-basis) or (legal-basis eq 'ANY')][(directive eq $directive) or (directive eq 'ANY')][(document-code eq $ted-form-document-code) or (document-code eq 'ANY')][1]"/>
	<!-- exit with an error if there is not exactly one matching row -->
	<xsl:if test="fn:count($mapping-row) != 1">
		<xsl:message terminate="yes">
			<xsl:text>ERROR: found </xsl:text>
			<xsl:choose>
				<xsl:when test="fn:count($mapping-row) = 0">no</xsl:when>
				<xsl:otherwise><xsl:value-of select="fn:count($mapping-row)"/> different</xsl:otherwise>
			</xsl:choose>
			<xsl:text> eForms subtype mappings for this Notice: </xsl:text><xsl:value-of select="$source-document"/><xsl:value-of select="$newline"/>
			<xsl:text>TED form element name: </xsl:text><xsl:value-of select="$ted-form-element"/><xsl:value-of select="$newline"/>
			<xsl:text>TED form name: </xsl:text><xsl:value-of select="$ted-form-name"/><xsl:value-of select="$newline"/>
			<xsl:text>TED form notice type: </xsl:text><xsl:value-of select="$ted-form-notice-type"/><xsl:value-of select="$newline"/>
			<xsl:text>TED form legal basis: </xsl:text><xsl:value-of select="$legal-basis"/><xsl:value-of select="$newline"/>
			<xsl:text>TED form directive: </xsl:text><xsl:value-of select="$directive"/><xsl:value-of select="$newline"/>
			<xsl:text>TED form document code: </xsl:text><xsl:value-of select="$ted-form-document-code"/><xsl:value-of select="$newline"/>
		</xsl:message>
	</xsl:if>
	<!-- read the eForms notice subtype from the row -->
	<xsl:variable name="eforms-subtype" select="$mapping-row/fn:string(eforms-subtype)"/>
	<!-- exit with an error if the eForms notice subtype is not a recognised value for the converter -->
	<xsl:choose>
		<xsl:when test="$eforms-subtype eq ''">
			<xsl:message terminate="yes">
				<xsl:text>ERROR: no eForms subtype mapping available for this Notice:</xsl:text><xsl:value-of select="$source-document"/><xsl:value-of select="$newline"/>
				<xsl:text>TED form element name: </xsl:text><xsl:value-of select="$ted-form-element"/><xsl:value-of select="$newline"/>
				<xsl:text>TED form name: </xsl:text><xsl:value-of select="$ted-form-name"/><xsl:value-of select="$newline"/>
				<xsl:text>TED form notice type: </xsl:text><xsl:value-of select="$ted-form-notice-type"/><xsl:value-of select="$newline"/>
				<xsl:text>TED form legal basis: </xsl:text><xsl:value-of select="$legal-basis"/><xsl:value-of select="$newline"/>
				<xsl:text>TED form directive: </xsl:text><xsl:value-of select="$directive"/><xsl:value-of select="$newline"/>
				<xsl:text>TED form document code: </xsl:text><xsl:value-of select="$ted-form-document-code"/><xsl:value-of select="$newline"/>
			</xsl:message>
		</xsl:when>
		<xsl:when test="$eforms-subtype eq 'ERROR'">
			<xsl:message terminate="yes">
				<xsl:text>ERROR: The combination of data in this Notice is considered an error:</xsl:text><xsl:value-of select="$source-document"/><xsl:value-of select="$newline"/>
				<xsl:text>TED form element name: </xsl:text><xsl:value-of select="$ted-form-element"/><xsl:value-of select="$newline"/>
				<xsl:text>TED form name: </xsl:text><xsl:value-of select="$ted-form-name"/><xsl:value-of select="$newline"/>
				<xsl:text>TED form notice type: </xsl:text><xsl:value-of select="$ted-form-notice-type"/><xsl:value-of select="$newline"/>
				<xsl:text>TED form legal basis: </xsl:text><xsl:value-of select="$legal-basis"/><xsl:value-of select="$newline"/>
				<xsl:text>TED form directive: </xsl:text><xsl:value-of select="$directive"/><xsl:value-of select="$newline"/>
				<xsl:text>TED form document code: </xsl:text><xsl:value-of select="$ted-form-document-code"/><xsl:value-of select="$newline"/>
			</xsl:message>
		</xsl:when>
		<xsl:when test="fn:not(fn:matches($eforms-subtype, '^[1-9]|[1-3][0-9]|40*$'))">
			<xsl:message terminate="yes">
				<xsl:text>ERROR: Conversion for eForms subtype </xsl:text>
				<xsl:value-of select="$eforms-subtype"/>
				<xsl:text> is not supported by this version of the converter</xsl:text>
			</xsl:message>
		</xsl:when>
	</xsl:choose>
	<!-- return the valid eForms notice subtype -->
	<xsl:value-of select="$eforms-subtype"/>
</xsl:function>



<!-- GENERAL FUNCTIONS -->

<!-- Function opfun:descendants-deep-equal compares the contents of two nodes, returning TRUE or FALSE. The names of the root node elements are ignored -->
<xsl:function name="opfun:descendants-deep-equal" as="xs:boolean">
	<xsl:param name="node1" as="node()"/>
	<xsl:param name="node2" as="node()"/>
	<xsl:variable name="out1">
		<out>
			<xsl:for-each select="$node1/node()">
				<xsl:copy-of select="."/>
			</xsl:for-each>
		</out>
	</xsl:variable>
	<xsl:variable name="out2">
		<out>
			<xsl:for-each select="$node2/node()">
				<xsl:copy-of select="."/>
			</xsl:for-each>
		</out>
	</xsl:variable>
	<xsl:value-of select="fn:deep-equal($out1, $out2)"/>
</xsl:function>

<!-- Function opfun:prefix-and-name returns the namespace prefix and local name of a given element, e.g. "cbc:ID" -->
<xsl:function name="opfun:prefix-and-name" as="xs:string">
	<xsl:param name="elem" as="element()"/>
	<xsl:variable name="name" select="$elem/fn:local-name()"/>
	<xsl:variable name="prefix" select="fn:prefix-from-QName(fn:node-name($elem))"/>
	<xsl:value-of select="fn:string-join(($prefix,$name),':')"/>
</xsl:function>

<!-- Function opfun:name-with-pos returns the name of the given element, and its sequence number as a predicate if there are more than one instance within its parent -->
<!-- Adapted from functx:path-to-node-with-pos, FunctX XSLT Function Library -->
<xsl:function name="opfun:name-with-pos" as="xs:string">
  <xsl:param name="element" as="element()"/>
  <xsl:variable name="sibsOfSameName" select="$element/../*[name() = name($element)]"/>
  <xsl:sequence select="concat(name($element),
         if (count($sibsOfSameName) &lt;= 1)
         then ''
         else concat('[',functx:index-of-node($sibsOfSameName,$element),']'))"/>
</xsl:function>


<!-- Message Functions -->

<xsl:template name="report-warning">
	<xsl:param name="message" as="xs:string"/>
	<xsl:if test="$showwarnings=1">
		<xsl:message terminate="no"><xsl:value-of select="$message"/></xsl:message>
	</xsl:if>
	<xsl:if test="$includewarnings=1">
		<xsl:comment><xsl:value-of select="$message"/></xsl:comment>
	</xsl:if>
</xsl:template>

<xsl:template name="include-comment">
	<xsl:param name="comment" as="xs:string"/>
	<xsl:if test="$includecomments=1">
		<xsl:comment><xsl:value-of select="$comment"/></xsl:comment>
	</xsl:if>
</xsl:template>

<xsl:template name="find-element">
	<xsl:param name="context" as="element()"/>
	<xsl:param name="relative-context" as="xs:string"/>
	<xsl:variable name="child-name-and-pos" select="functx:substring-before-if-contains($relative-context, '/')"/>
	<xsl:variable name="next-context" select="fn:substring-after($relative-context, '/')"/>
	<xsl:variable name="element" select="$context/*[opfun:name-with-pos(.) = $child-name-and-pos]"/>
	<xsl:variable name="result">
		<xsl:choose>
			<xsl:when test="not($element)"><xsl:sequence select="()"/></xsl:when>
			<xsl:when test="$next-context">
				<xsl:call-template name="find-element">
					<xsl:with-param name="context" select="$element"/>
					<xsl:with-param name="relative-context" select="$next-context"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise><xsl:sequence select="$element"/></xsl:otherwise>
		</xsl:choose>
	</xsl:variable>
	<xsl:sequence select="$result"/>
</xsl:template>

<xsl:template name="multilingual">
	<xsl:param name="contexts" as="node()*"/>
	<xsl:param name="local"/>
	<xsl:param name="element"/>
	<xsl:variable name="relative-contexts" select="for $context in $contexts return fn:substring-after(functx:path-to-node-with-pos($context), fn:concat($ted-form-element-xpath, '/'))"/>
	<xsl:choose>
		<xsl:when test="$ted-form-additional-elements">
			<xsl:for-each select="($ted-form-main-element, $ted-form-additional-elements)">
				<xsl:variable name="language" select="opfun:get-eforms-language(@LG)"/>
				<xsl:variable name="form-element" select="."/>
				<xsl:variable name="text-content">
				<xsl:for-each select="$relative-contexts">
					<xsl:variable name="relative-context" select="."/>
					<xsl:variable name="this-context" select="fn:concat(functx:path-to-node-with-pos($form-element), .)"/>
					<xsl:variable name="parent">
						<xsl:call-template name="find-element">
							<xsl:with-param name="context" select="$form-element"/>
							<xsl:with-param name="relative-context" select="$relative-context"/>
						</xsl:call-template>
					</xsl:variable>
					<xsl:choose>
						<xsl:when test="$local eq ''">
							<xsl:value-of select="fn:normalize-space($parent/*)"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="fn:normalize-space(fn:string-join($parent/*/*[fn:local-name() = $local], ' '))"/>
						</xsl:otherwise>
					</xsl:choose>
					<xsl:text> </xsl:text>
				</xsl:for-each>
				</xsl:variable>
				<xsl:element name="{$element}">
					<xsl:attribute name="languageID" select="$language"/>
					<xsl:value-of select="fn:normalize-space(fn:string-join($text-content, ' '))"/>
				</xsl:element>
			</xsl:for-each>
		</xsl:when>
		<xsl:otherwise>
			<xsl:variable name="text" as="xs:string">
				<xsl:choose>
					<xsl:when test="$local eq ''">
						<xsl:value-of select="fn:normalize-space($contexts)"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="fn:normalize-space(fn:string-join($contexts/*[fn:local-name() = $local], ' '))"/>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>
			<xsl:element name="{$element}">
				<xsl:attribute name="languageID" select="$eforms-first-language"/>
				<xsl:value-of select="$text"/>
			</xsl:element>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

	<!-- Functions in the uuid: namespace are used to calculate a UUID The method used is a derived timestamp method, which 
		is explained here: http://www.famkruithof.net/guid-uuid-timebased.html and here: http://www.ietf.org/rfc/rfc4122.txt -->
	<!-- Returns the UUID -->
	<xsl:function name="uuid:get-uuid" as="xs:string*">
		<xsl:param name="node"/>
		<xsl:variable name="ts" select="uuid:ts-to-hex(uuid:generate-timestamp($node))"/>
		<xsl:value-of separator="-" select="             substring($ts, 8, 8),             substring($ts, 4, 4),             string-join((uuid:get-uuid-version(), substring($ts, 1, 3)), ''),             uuid:generate-clock-id(),             uuid:get-network-node()"/>
	</xsl:function>
	<!-- internal aux. fu with saxon, this creates a more-unique result with generate-id then when just using a variable containing 
		a node -->
	<xsl:function name="uuid:_get-node">
		<xsl:comment/>
	</xsl:function>
	<!-- should return the next nr in sequence, but this can't be done in xslt. Instead, it returns a guaranteed unique number -->
	<xsl:function name="uuid:next-nr" as="xs:integer">
		<xsl:param name="node"/>
		<xsl:sequence select="             xs:integer(replace(             generate-id($node), '\D', ''))"/>
	</xsl:function>
	<!-- internal fu for returning hex digits only -->
	<xsl:function name="uuid:_hex-only" as="xs:string">
		<xsl:param name="string"/>
		<xsl:param name="count"/>
		<xsl:sequence select="             substring(replace(             $string, '[^0-9a-fA-F]', '')             , 1, $count)"/>
	</xsl:function>
	<!-- may as well be defined as returning the same seq each time -->
	<xsl:variable name="_clock" select="generate-id(uuid:_get-node())"/>
	<xsl:function name="uuid:generate-clock-id" as="xs:string">
		<xsl:sequence select="uuid:_hex-only($_clock, 4)"/>
	</xsl:function>
	<!-- returns the network node, this one is 'random', but must be the same within calls. The least-significant bit must be 
		'1' when it is not a real MAC address (in this case it is set to '1') -->
	<xsl:function name="uuid:get-network-node" as="xs:string">
		<xsl:sequence select="uuid:_hex-only('09-17-3F-13-E4-C5', 12)"/>
	</xsl:function>
	<!-- returns version, for timestamp uuids, this is "1" -->
	<xsl:function name="uuid:get-uuid-version" as="xs:string">
		<xsl:sequence select="'1'"/>
	</xsl:function>
	<!-- Generates a timestamp of the amount of 100 nanosecond intervals from 15 October 1582, in UTC time. -->
	<xsl:function name="uuid:generate-timestamp">
		<xsl:param name="node"/>
		<!-- date calculation automatically goes correct when you add the timezone information, in this case that is UTC. -->
		<xsl:variable name="duration-from-1582" as="xs:dayTimeDuration">
			<xsl:sequence select="                 current-dateTime() -                 xs:dateTime('1582-10-15T00:00:00.000Z')"/>
		</xsl:variable>
		<xsl:variable name="random-offset" as="xs:integer">
			<xsl:sequence select="uuid:next-nr($node) mod 10000"/>
		</xsl:variable>
		<!-- do the math to get the 100 nano second intervals -->
		<xsl:sequence select="             (days-from-duration($duration-from-1582) * 24 * 60 * 60 +             hours-from-duration($duration-from-1582) * 60 * 60 +             minutes-from-duration($duration-from-1582) * 60 +             seconds-from-duration($duration-from-1582)) * 1000             * 10000 + $random-offset"/>
	</xsl:function>
	<!-- simple non-generalized function to convert from timestamp to hex -->
	<xsl:function name="uuid:ts-to-hex">
		<xsl:param name="dec-val"/>
		<xsl:value-of separator="" select="             for $i in 1 to 15             return (0 to 9, tokenize('A B C D E F', ' '))             [             $dec-val idiv             xs:integer(math:power(16, 15 - $i))             mod 16 + 1             ]"/>
	</xsl:function>
	<xsl:function name="math:power">
		<xsl:param name="base"/>
		<xsl:param name="power"/>
		<xsl:choose>
			<xsl:when test="$power &lt; 0 or contains(string($power), '.')">
				<xsl:message terminate="yes">
					
					The XSLT template math:power doesn't support negative or
					
					fractional arguments.
					
				</xsl:message>
				<xsl:text>NaN</xsl:text>
			</xsl:when>
			<xsl:otherwise>
				<xsl:call-template name="math:_power">
					<xsl:with-param name="base" select="$base"/>
					<xsl:with-param name="power" select="$power"/>
					<xsl:with-param name="result" select="1"/>
				</xsl:call-template>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:function>
	<xsl:template name="math:_power">
		<xsl:param name="base"/>
		<xsl:param name="power"/>
		<xsl:param name="result"/>
		<xsl:choose>
			<xsl:when test="$power = 0">
				<xsl:value-of select="$result"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:call-template name="math:_power">
					<xsl:with-param name="base" select="$base"/>
					<xsl:with-param name="power" select="$power - 1"/>
					<xsl:with-param name="result" select="$result * $base"/>
				</xsl:call-template>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:stylesheet>
