# -*- coding: utf-8 -*-
# +
*** Settings ***
Documentation   Order robots from robotsparebin industries
...             Save the receipt HTML in a pdf file
...             Take screenshot of robot and attach in pdf file
...             Zip the all reciepts

Library    RPA.HTTP
Library    RPA.Browser.Selenium
Library    RPA.Tables 
Library    RPA.PDF
Library    RPA.FileSystem
Library    RPA.Archive
Library    Dialogs
Library    RPA.Dialogs
Library    Collections
Library    RPA.Robocloud.Secrets
Library    RPA.Robocorp.Vault
Library    Process
# -


*** Variables ***
${GLOBAL_RETRY_AMOUNT}=    6x
${GLOBAL_RETRY_INTERVAL}=    0.6s

*** Keywords ***
Open browser 

       ${secret}=   RPA.Robocorp.Vault.Get Secret      enlaces
       RPA.Browser.Selenium.Open Available Browser    ${secret}[enlace-orden] 
       
       #RPA.Browser.Selenium.Click Element    css: .btn-dark

*** Keywords ***
Input
      ${userInputUrl}=    Dialogs.Get Value From User   Url of the CSV file:
      Log  ${userInputUrl}
      [Return]    ${userInputUrl}
       
      # Url: https://robotsparebinindustries.com/orders.csv

*** Keywords ***
Download CSV file
        [Arguments]  ${downloadUrl}
        ${ordersFile}=  RPA.HTTP.Download       ${downloadUrl}    ${CURDIR}${/}output${/}orders.csv   overwrite=True
        [Return]   ${ordersFile}

*** Keywords ***
Read CSV
        [Arguments]  ${ordersFile}
        
        ${ordersTable}=    Read table from CSV     ${ordersFile}
        [Return]    ${ordersTable}

*** Keywords ***
Complete and submit the form for person
        
        [Arguments]    ${order}
        #Btn
        RPA.Browser.Selenium.Click Element    css: .btn-dark  
        
        # Complete orden
        RPA.Browser.Selenium.Select From List By Value  //select[@name="head"]  ${order}[Head]
        RPA.Browser.Selenium.Click Element  //input[@value="${order}[Body]"]
        RPA.Browser.Selenium.Input Text  id= address  ${order}[Address]
        ${Legs_as_string}=  Convert To String  ${order}[Legs]
        RPA.Browser.Selenium.Input Text  //input[@placeholder="Enter the part number for the legs"]    ${Legs_as_string}
        
         # Preview
            Wait Until Keyword Succeeds    #5x    1s
            ...    ${GLOBAL_RETRY_AMOUNT}
            ...    ${GLOBAL_RETRY_INTERVAL}
            ...    RPA.Browser.Selenium.Wait Until Page Contains Element   id=preview

            FOR    ${i}    IN RANGE    5            
                RPA.Browser.Selenium.Click Button    id=preview
                # Checking if submit is Ok!
                    ${submit_Ok}=    Does Page Contain Element    id=robot-preview-image
                    # Log    ${submit_Ok}
                    Exit For Loop If    ${submit_Ok}
             END
             
         #Order
            Wait Until Keyword Succeeds
            ...    ${GLOBAL_RETRY_AMOUNT}
            ...    ${GLOBAL_RETRY_INTERVAL}
            ...    RPA.Browser.Selenium.Wait Until Page Contains Element    id:order
        
             FOR    ${i}    IN RANGE    5
                    RPA.Browser.Selenium.Click Button    id:order
                    # Checking if submit is Ok!
                    ${submit_Ok}=    Does Page Contain    Receipt
                    # Log    ${submit_Ok}
                    Exit For Loop If    ${submit_Ok}
             END

*** Keywords ***
Create receipts
    [Arguments]  ${order}  
    #Receipt
        #RPA.Browser.Selenium.Wait Until Element Is Visible    id:receipt
            Wait Until Keyword Succeeds    #5x    1s
            ...    ${GLOBAL_RETRY_AMOUNT}
            ...    ${GLOBAL_RETRY_INTERVAL}
            ...    RPA.Browser.Selenium.Wait Until Page Contains Element  id:receipt
            
            ${recibo}=   RPA.Browser.Selenium.Get Element Attribute    id:receipt   outerHTML
            Html To Pdf    ${recibo}    ${CURDIR}${/}output${/}receipts${/}${order}[Order number].PDF
         
    #Screenshot of robot preview image
        ${screenshot}=  RPA.Browser.Selenium.Screenshot   id=robot-preview-image    ${CURDIR}${/}output${/}${order}[Order number].png
       # [Return]   ${CURDIR}${/}output${/}${order}[Order number].png

    #Adjunt ss in pdf   ${screenshot}    ${pdf}
        RPA.PDF.Add Watermark Image To Pdf  ${CURDIR}${/}output${/}${order}[Order number].png   ${CURDIR}${/}output${/}receipts${/}${order}[Order number].PDF   ${CURDIR}${/}output${/}receipts${/}${order}[Order number].PDF
        RPA.FileSystem.Remove File  ${CURDIR}${/}output${/}${order}[Order number].png
        
        [Return]     ${CURDIR}${/}output${/}receipts${/}${order}[Order number].PDF
        Close Pdf       ${CURDIR}${/}output${/}receipts${/}${order}[Order number].PDF  

*** Keywords ***
Create ZIP
        [Arguments]    ${order}
        RPA.Archive.Archive Folder With Zip  ${CURDIR}${/}output${/}receipts  ${CURDIR}${/}Output${/}receipts.zip
        #[Return]  ${CURDIR}${/}Output${/}receipts.zip
        #Wait For Process	timeout=2 secs
        RPA.FileSystem.Remove Directory    ${CURDIR}${/}output${/}receipts    recursive=true
        #RPA.FileSystem.Remove File  ${CURDIR}${/}output${/}receipts  ignore non-existent file

*** Keywords ***
Order another
    Wait Until Keyword Succeeds    #5x    1s
    ...    ${GLOBAL_RETRY_AMOUNT}
    ...    ${GLOBAL_RETRY_INTERVAL}
    ...    RPA.Browser.Selenium.Wait Until Page Contains Element  id:order-another
    RPA.Browser.Selenium.Click Button    id:order-another


*** Keywords ***
Orders robots and create receipts
        ${orders}=   Read table from CSV    orders.csv    
        FOR    ${order}      IN      @{orders}
            Complete and submit the form for person    ${order}
            Create receipts    ${order}  
            Order another
        END
        Create ZIP    ${order}

*** Keywords ***
Close browser
     RPA.Browser.Selenium.Close Browser

*** Tasks ***
Minimal task
   ${downloadUrl}=   Input  
   Log  ${downloadUrl}
   
   ${download}=   Download CSV file   ${downloadUrl}
   Log  ${download}
   
   Download CSV file    ${downloadUrl}
   
   ${orders}=   Read CSV   ${downloadUrl}
   Log      ${orders}
   
   Open browser 
   Orders robots and create receipts
   [Teardown]   Close browser
