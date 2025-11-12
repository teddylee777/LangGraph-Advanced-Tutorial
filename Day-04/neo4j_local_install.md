# 1. Neo4J Desktop 환경 설정

## Neo4J Docker Load & Run: 
    - `sh 2_docker_image_load.sh`
    - `sh 3_neo4j_docker_run.sh`
    - 초기 
        ID: neo4j
        PW: neo4j

### nori 형태소 분석기 설치 확인: 
    - Neo4J Query 도구를 실행하고 다음의 Cypher 쿼리를 실행하고 'nori' 토크나이저를 목록에서 확인
    ```cypher
    CALL db.index.fulltext.listAvailableAnalyzers()
    ```