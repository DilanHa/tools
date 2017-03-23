<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:html="http://www.w3.org/1999/xhtml" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xd="http://www.pnp-software.com/XSLTdoc" xmlns:opf="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:bgn="http://bibliograph.net/" xmlns:genont="http://www.w3.org/2006/gen/ont#" xmlns:pto="http://www.productontology.org/id/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:re="http://oclcsrw.google.code/redirect" xmlns:schema="http://schema.org/" xmlns:umbel="http://umbel.org/umbel#"
    xmlns:srw="http://www.loc.gov/zing/srw/"
    xmlns:viaf="http://viaf.org/viaf/terms#"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xi="http://www.w3.org/2001/XInclude" xpath-default-namespace="http://www.tei-c.org/ns/1.0"
    exclude-result-prefixes="xs xd xi dc opf html" version="2.0">
    
    <!-- this stylesheet  tries to query external authority files if they are linked through the @ref attribute -->
    <xsl:output method="xml" encoding="UTF-8" indent="yes" exclude-result-prefixes="#all"/>
    
   
    
    <!-- query VIAF and return RDF -->
    <xsl:template name="t_query-viaf-rdf">
        <xsl:param name="p_viaf-id"/>
        <xsl:variable name="v_viaf-rdf" select="doc(concat('https://viaf.org/viaf/',$p_viaf-id,'/rdf.xml'))"/>
        <!-- add VIAF ID -->
        <xsl:element name="tei:idno">
            <xsl:attribute name="type" select="'viaf'"/>
            <xsl:value-of select="$p_viaf-id"/>
        </xsl:element>
        <!-- add birth and death dates -->
        <xsl:apply-templates select="$v_viaf-rdf//rdf:RDF/rdf:Description/schema:birthDate"/>
        <xsl:apply-templates select="$v_viaf-rdf//rdf:RDF/rdf:Description/schema:deathDate"/>
    </xsl:template>
    
    <xsl:template match="schema:birthDate | viaf:birthDate">
        <xsl:element name="tei:birth">
            <xsl:call-template name="t_dates-normalise">
                <xsl:with-param name="p_input" select="."/>
            </xsl:call-template>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="schema:deathDate | viaf:deathDate">
        <xsl:element name="tei:death">
            <xsl:call-template name="t_dates-normalise">
                <xsl:with-param name="p_input" select="."/>
            </xsl:call-template>
        </xsl:element>
    </xsl:template>
    
    <!-- query VIAF using SRU -->
    <xsl:template name="t_query-viaf-sru">
        <xsl:param name="p_search-term"/>
        <xsl:param name="p_input-type"/>
        <xsl:param name="p_records-max" select="3"/>
        <xsl:variable name="v_viaf-sru">
            <xsl:choose>
                <xsl:when test="$p_input-type='id'">
                    <xsl:copy-of select="doc(concat('https://viaf.org/viaf/search?query=local.viafID+any+&quot;',$p_search-term,'&quot;&amp;httpAccept=application/xml'))"/>
                </xsl:when>
                <xsl:when test="$p_input-type='persName'">
                    <xsl:copy-of select="doc(concat('https://viaf.org/viaf/search?query=local.personalNames+any+&quot;',$p_search-term,'&quot;','&amp;maximumRecords=',$p_records-max,'&amp;httpAccept=application/xml'))"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:copy-of select="doc(concat('https://viaf.org/viaf/search?query=cql.any+all+',$p_search-term,'&amp;maximumRecords=',$p_records-max,'&amp;httpAccept=application/xml'))"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="v_record-1" select="$v_viaf-sru/descendant-or-self::srw:searchRetrieveResponse/srw:records/srw:record[1]/srw:recordData[@xsi:type='ns1:stringOrXmlFragment']/viaf:VIAFCluster"/>
        <xsl:variable name="v_viaf-id" select="$v_record-1//viaf:viafID"/>
        <!-- add VIAF ID -->
        <xsl:element name="tei:idno">
            <xsl:attribute name="type" select="'viaf'"/>
            <xsl:value-of select="$v_viaf-id"/>
        </xsl:element>
        <!-- add birth and death dates -->
        <xsl:apply-templates select="$v_record-1//viaf:birthDate"/>
        <xsl:apply-templates select="$v_record-1//viaf:deathDate"/>
    </xsl:template>
    
    <xsl:template name="t_dates-normalise">
        <!-- the dates returned by VIAF can be formatted as
            - yyyy-mm-dd: no issue
            - yyy-mm-dd: the year needs an additional leading 0
            - yyyy-mm-00: this indicates a date range of a full month
        -->
        <xsl:param name="p_input"/>
        <xsl:analyze-string select="$p_input" regex="(\d{{4}})$|(\d{{3,4}})-(\d{{2}})-(\d{{2}})$">
            <xsl:matching-substring>
                <xsl:element name="tei:date">
                    <xsl:variable name="v_year">
                        <xsl:value-of select="format-number(number(regex-group(2)),'0000')"/>
                    </xsl:variable>
                    <xsl:variable name="v_month">
                        <xsl:value-of select="format-number(number(regex-group(3)),'00')"/>
                    </xsl:variable>
                    <!-- check if the result is a date range -->
                    <xsl:choose>
                        <xsl:when test="regex-group(4)='00'">
                            <xsl:attribute name="notBefore" select="concat($v_year,'-',$v_month,'-01')"/>
                            <!-- in order to not produce invalid dates, we pretend that all Gregorian months have only 28 days-->
                            <xsl:attribute name="notAfter" select="concat($v_year,'-',$v_month,'-28')"/>
                        </xsl:when>
                        <xsl:when test="regex-group(2)">
                            <xsl:attribute name="when" select="concat($v_year,'-',$v_month,'-',regex-group(4))"/>
                        </xsl:when>
                        <xsl:when test="regex-group(1)">
                            <xsl:attribute name="when" select="regex-group(1)"/>
                        </xsl:when>
                    </xsl:choose>
                    <xsl:value-of select="$p_input"/>
                </xsl:element>
            </xsl:matching-substring>
        </xsl:analyze-string>
    </xsl:template>
    
    
</xsl:stylesheet>