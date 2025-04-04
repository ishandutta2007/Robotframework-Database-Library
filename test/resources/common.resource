*** Settings ***
Documentation       Global variables, which are used in all test common tests
...                 and which should be set outside at the test execution start (e.g. in CI pipeline)

Library             Collections
Library             OperatingSystem
Library             DatabaseLibrary
Library             DateTime
Resource            config_files/connect_config_file.resource


*** Variables ***
${DB_MODULE_MODE}       standard
${DB_MODULE}            psycopg2
${DB_HOST}              127.0.0.1
${DB_NAME}              db
${DB_PASS}              pass
${DB_PORT}              5432
${DB_USER}              db_user

# used for MySQL via PyODBC only
${DB_DRIVER}            ODBC Driver 18 for SQL Server

# Oracle via Jaydebeapi
${DRIVER_PATH}          ${CURDIR}/ojdbc17.jar
${DRIVER_CLASSNAME}     oracle.jdbc.driver.OracleDriver
&{DRIVER_ARGS}          user=${DB_USER}    password=${DB_PASS}
${JDBC_URL}             jdbc:oracle:thin:@${DB_HOST}:${DB_PORT}/${DB_NAME}


*** Keywords ***
Connect To DB
    [Documentation]    Connects to the database based on the current DB module under test
    ...    and connection params set in global variables with alias
    [Arguments]    ${alias}=${None}
    ${DB_KWARGS}=    Create Dictionary
    IF    $alias is not None
        Set To Dictionary    ${DB_KWARGS}    alias=${alias}
    END
    IF    "${DB_MODULE_MODE}" == "custom"
        IF    "${DB_MODULE}" == "sqlite3"
            Remove File    ${DBName}.db
            Connect To Database    sqlite3    database=./${DBName}.db    isolation_level=${None}
            ...    &{DB_KWARGS}
        ELSE IF    "${DB_MODULE}" == "jaydebeapi"
            Connect To Database    ${DB_MODULE}    jclassname=${DRIVER_CLASSNAME}    url=${JDBC_URL}
            ...    driver_args=${DRIVER_ARGS}    jars=${DRIVER_PATH}    &{DB_KWARGS}
            Set Auto Commit    False    alias=${alias}
            Set Omit Trailing Semicolon    True    alias=${alias}
        ELSE
            ${Connection String}=    Build Connection String
            Connect To Database Using Custom Connection String    ${DB_MODULE}    ${Connection String}    &{DB_KWARGS}
        END
    ELSE IF    "${DB_MODULE_MODE}" == "standard"
        ${DB_ARGS}=    Create List
        ...    ${DB_MODULE}
        ...    ${DB_NAME}
        ...    ${DB_USER}
        ...    ${DB_PASS}
        ...    ${DB_HOST}
        ...    ${DB_PORT}
        IF    "${DB_MODULE}" == "pyodbc"
            Set To Dictionary    ${DB_KWARGS}    odbc_driver=${DB_DRIVER}
        END
        Connect To Database    @{DB_ARGS}    &{DB_KWARGS}
    ELSE
        Fail    Unexpected mode - ${DB_MODULE_MODE}
    END

Build Connection String
    [Documentation]    Returns the connection string variable depending on the DB module
    ...    currently under test.
    IF    "${DB_MODULE}" == "oracledb"
        ${Result}=    Set Variable
        ...    ${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}
    ELSE IF    "${DB_MODULE}" == "psycopg2"
        ${Result}=    Set Variable
        ...    postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}
    ELSE
        Skip    Don't know how to build a connection string for '${DB_MODULE}'
    END
    RETURN    ${Result}

Create Person Table
    ${sql}=    Catenate
    ...    CREATE TABLE person
    ...    (id integer not null unique, FIRST_NAME varchar(20), LAST_NAME varchar(20))
    ${output}=    Execute Sql String    ${sql}
    RETURN    ${output}

Create Person Table And Insert Data
    Create Person Table
    Insert Data In Person Table Using SQL Script

Insert Data In Person Table Using SQL Script
    [Arguments]    ${alias}=${None}
    IF    $alias is None
        ${output}=    Execute SQL Script    ${CURDIR}/insert_data_in_person_table.sql
    ELSE
        ${output}=    Execute SQL Script    ${CURDIR}/insert_data_in_person_table.sql    alias=${alias}
    END
    RETURN    ${output}

Create Foobar Table
    ${sql}=    Catenate
    ...    CREATE TABLE foobar
    ...    (id integer not null primary key, FIRST_NAME varchar(30) not null unique)
    ${output}=    Execute Sql String    ${sql}
    RETURN    ${output}

Create Foobar Table And Insert Data
    Create Foobar Table
    Execute SQL String    INSERT INTO foobar VALUES(1,'Jerry')

Create Tables Person And Foobar
    Create Person Table
    Create Foobar Table

Drop Tables Person And Foobar
    Sleep    1s
    FOR    ${table}    IN    person    foobar
        ${exists}=    Run Keyword And Return Status
        ...    Table Must Exist    ${table}
        IF    ${exists}    Execute Sql String    DROP TABLE ${table}
    END
