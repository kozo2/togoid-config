## endopoint https://integbio.jp/rdf/bioportal/sparql
PREFIX oboInOwl: <http://www.geneontology.org/formats/oboInOwl#>

SELECT DISTINCT ?ordo_id ?mesh_id
FROM <http://integbio.jp/rdf/mirror/bioportal/ordo>
WHERE {
  ?ordo_uri
    oboInOwl:hasDbXref ?mesh.
  FILTER(contains(?mesh,'MeSH:'))
  BIND (replace(str(?mesh), "MeSH:", "") AS ?mesh_id)
  BIND (replace(str(?ordo_uri), "http://www.orpha.net/ORDO/Orphanet_", "") AS ?ordo_id) 
   }
