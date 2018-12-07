xquery version "3.0";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace html="http://www.w3.org/1999/xhtml";
declare option exist:serialize "method=xml";
declare option exist:serialize "indent=yes";
declare option exist:serialize "omit-xml-declaration=no";
declare option exist:serialize "process-xsl-pi=yes";


import module namespace kwic="http://exist-db.org/xquery/kwic";


(: try to search for terms using lucence and kwic :)

(: the term(s) to be searched for :)
let $v_collection :=request:get-parameter('col','muqtabas')
let $v_title := request:get-parameter('title','المقتبس')

(: Call data sources :)
(: let $v_library := collection(concat('/db/DAPE/xml_',$v_collection)) :)
let $v_library := collection('/db/DAPE/')
let $v_file := doc (concat('/db/DAPE/xml_',$v_collection,'/oclc_4770057679-i_63.TEIP5.xml'))
let $v_teis := $v_library/descendant-or-self::tei:TEI[tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:biblStruct/tei:monogr/tei:title[@xml:lang='ar'][not(@type='sub')]=$v_title]
(: let $v_divs := $v_library/descendant::tei:body/descendant::tei:div[@type='article'] :)

(: link to edition: https://rawgit.com/tillgrallert/digital-muqtabas/master , file:///Volumes/Dessau%20HD/BachUni/BachBibliothek/GitHub/digital-muqtabas :)
let $v_url-base := 'https://rawgit.com/tillgrallert/digital-muqtabas/master'

(: call stylesheet :)
let $v_teibp := doc('/db/DAPE/xslt-boilerplate/teibp.xsl')

(: the search function :)
let $v_query := request:get-parameter('search', 'المرأة')
let $v_node-name := request:get-parameter('node','p')
(: this defines the leading wildcard option of ft:query, which, however seems not to work with kwic :)
let $v_ft-query-option := <options><default-operator>and</default-operator><leading-wildcard>yes</leading-wildcard></options>
(: what are the properties of ft:query? it allows for Bolean operators! ft:query(., $v_query, $v_ft-query-option) :)

(: construct a search form :)
let $v_form-search :=
    <tei:div xml:lang="en">
        <form action="search.xql" method="get">
            <tei:p>
                <span lang="en">Search: </span>
                <input lang="ar" type="text" name="node" size="7" value="{$v_node-name}"/>
                <span lang="en"> elements in </span>
                <input lang="ar" type="text" name="title" size="10" value="{$v_title}" style="text-align:right;direction: rtl;"/>
                <span lang="en"> for </span> 
                <input lang="ar" type="text" name="search" size="80" value="{$v_query}" style="text-align:right;direction: rtl;"/>
                <input class="gobox" type="submit" value="GO" />
                </tei:p>
        </form>
    </tei:div>

(: produce the final output :)
let $v_hits := 
    <tei:teiCorpus xmlns:tei="http://www.tei-c.org/ns/1.0">
        {$v_form-search}
        <tei:teiHeader xml:lang="en"/>
            {for $v_tei in $v_teis[ft:query(descendant::tei:div[@type='article']/descendant::node()[name()=$v_node-name][not(self::tei:div)], $v_query, $v_ft-query-option)]
                let $v_id := string($v_tei/@xml:id)
                let $v_source := $v_tei/tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:biblStruct
                let $v_volume := $v_source/descendant::tei:biblScope[@unit='volume']
                let $v_issue := $v_source/descendant::tei:biblScope[@unit='issue']
                order by number($v_volume/@n) ascending, number($v_issue/@n) ascending
                return 
                <tei:TEI xml:id="{$v_id}">
                {$v_tei/tei:teiHeader, $v_tei/tei:facsimile}
                <tei:text xml:lang="ar">
                    <tei:front>
                        <tei:div xml:lang="en">{$v_id}</tei:div>
                     </tei:front>
                    <tei:body>
                    {
                    for $v_div in $v_tei/descendant::tei:div[@type='article'][ft:query(descendant::node()[name()=$v_node-name][not(self::tei:div)], $v_query, $v_ft-query-option)]
                        let $v_head := $v_div/tei:head[1]
                        let $v_id-div := concat($v_id,'.TEIP5.xml#',$v_div/@xml:id)
                        let $v_pb-preceding := $v_div/preceding::tei:pb[@ed='print'][1]
                        order by $v_head
                        return 
                        <tei:div>
                           <!--  {$v_pb-preceding} -->
                        <tei:div type="article" xml:id="{$v_div/@xml:id}">
                            {$v_div/tei:head}
                            <!-- link to complete issue -->
                            <a href="{$v_url-base}/xml/{$v_id-div}" target="_blank" lang="en">source</a>
                            {for $v_node in $v_div/descendant::node()[name()=$v_node-name][not(self::tei:div)][ft:query(., $v_query, $v_ft-query-option)]
                                let $v_pb-preceding := $v_node/preceding::tei:pb[@ed='print'][1]
                                return 
                                ($v_pb-preceding, $v_node)
                            }
                        </tei:div>
                        </tei:div>
                    }
                    </tei:body>
                </tei:text>
                </tei:TEI>
                }
    </tei:teiCorpus>
            
return transform:transform($v_hits, $v_teibp,())
(: return $v_hits :)