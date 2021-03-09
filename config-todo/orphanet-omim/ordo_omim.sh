#!/bin/sh
# 20210209 takatsuki
# SPARQL query
QUERY="PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX oboInOwl: <http://www.geneontology.org/formats/oboInOwl#>
PREFIX obo: <http://purl.obolibrary.org/obo/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema>
PREFIX ORDO: <http://www.orpha.net/ORDO/Orphanet_>
SELECT DISTINCT ?ORDO_ID ?OMIM_ID
FROM <http://integbio.jp/rdf/mirror/bioportal/ordo>
WHERE {
  ?s oboInOwl:hasDbXref ?id.
   FILTER(contains(?id,'OMIM'))
   BIND (replace(str(?id), "OMIM:", "") AS ?OMIM_ID)
   BIND (replace(str(?s), "http://www.orpha.net/ORDO/Orphanet_", "") AS ?ORDO_ID) 
        }"
# curl -> format -> delete header
curl -s -H "Accept: text/csv" --data-urlencode "query=$QUERY" https://integbio.jp/rdf/mirror/bioportal/sparql | sed -e 's/\"//g; s/,/\t/g; s/http:\/\/www.orpha.net\/ORDO\/Orphanet_//g; s/OMIM://' | sed -e '1d'
