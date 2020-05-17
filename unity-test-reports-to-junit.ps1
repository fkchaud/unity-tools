<#
.SYNOPSIS
    This script takes a unit test report from Unity3D Test Framework
    and converts it to JUnit test report format.
.DESCRIPTION
    This script takes a unit test reports from Unity3D Test Framework,
    hardcoded to be in the running folder and called "unit-tests.xml",
    loop over its content, and create an XML file with the JUnit test
    report format, hardcoded to be in the current folder and called
    "junit-tests.xml".
    This should be improved to take both source and destination files
    as a parameter.
#>


function GetTestFixtures ($xmlNode) {
    <#
    .SYNOPSIS
        Recursively inspects an XML node to return an array with <test-suite>s
        matching type of TestFixtures.
    .DESCRIPTION
        TestFixtures can be somewhat a mess regarding to in which level they
        are found, if the Test had a namespace or not, etc. To overcome this,
        nodes can be recursively inspected to find the <test-suite> tags
        matching a TestFixture.
    .PARAMETER xmlNode
        An xmlNode. Should have type 'TestFixture', or have a 'test-run' child
        node, or have one or more 'test-suite' childs.
    #>
    if ($xmlNode.type.Equals('TestFixture')) {
        return @($xmlNode);
    }
    if ($xmlNode.'test-run') {
        return GetTestFixtures($xmlNode.'test-run');
    }
    if (!($xmlNode.'test-suite')) {
        return @();
    }

    $testFixturesArray = @();
    $xmlNode.'test-suite' | ForEach-Object {
        $testFixturesArray += GetTestFixtures($_);
    }
    return $testFixturesArray;
}

# Read Unit Tests
$xmlSourceFilePath = ".\unit-tests.xml";
[XML]$xmlSourceObject = Get-Content $xmlSourceFilePath;

# Get only the TestFixtures
$testFixtures = GetTestFixtures($xmlSourceObject);

# Setup XmlWriter
# file path must be absolute path or XmlWriter won't know where to write
$outputFile = (Get-Location).Path + "\junit-tests.xml";
$XmlSettings = New-Object System.Xml.XmlWriterSettings;
$XmlSettings.Indent = $True;
$XmlWriter = [System.XML.XmlWriter]::Create($outputFile, $XmlSettings);

$XmlWriter.WriteStartDocument();
$XmlWriter.WriteStartElement('testsuites'); # <testsuites>
$testFixtures | ForEach-Object {
    $XmlWriter.WriteStartElement('testsuite'); # <testsuite ...>
    $XmlWriter.WriteAttributeString('id', $_.id); # <... id=1001 ...>
    $XmlWriter.WriteAttributeString('name', $_.classname); # <... name=Tests.TestSuite ...>
    # Note: Unity3D does not distinguish errors from failures in xml reports
    $XmlWriter.WriteAttributeString('errors', "0"); # <... errors=0 ...>
    $XmlWriter.WriteAttributeString('skipped', $_.skipped); # <... skipped=0 ...>
    $XmlWriter.WriteAttributeString('tests', $_.testcasecount); # <... tests=0 ...>
    $XmlWriter.WriteAttributeString('failures', $_.failed); # <... failures=0 ...>
    $XmlWriter.WriteAttributeString('time', $_.duration); # <... time=0.321 ...>
    $XmlWriter.WriteAttributeString(
        'timestamp',
        [datetime]::ParseExact(
            $_.'start-time',
            'yyyy-MM-dd HH:mm:ssZ',
            $null
        ).ToString('yyyy-MM-ddTHH:mm:ss')
    ); # <... timestamp="2020-05-17T12:35:12" >

    $_.'test-case' | ForEach-Object {
        $XmlWriter.WriteStartElement('testcase'); # <testcase ...>
        $XmlWriter.WriteAttributeString('classname', $_.classname); # <... classname=Tests.TestSuite ...>
        $XmlWriter.WriteAttributeString('name', $_.name); # <... name=TestSomething ...>
        $XmlWriter.WriteAttributeString('time', $_.duration); # <... time=0.123 >
        if ($_.result.Equals('Failed')) {
            $XmlWriter.WriteStartElement('failure'); # <failure ...>
            $XmlWriter.WriteAttributeString('message', $_.failure.message.InnerText); # <... message="AttributeError" ...>
            # Unity does not provide information about the failure type but it is required for JUnit XML
            $XmlWriter.WriteAttributeString('type', ''); # <... type="" >
            $XmlWriter.WriteString($_.failure.'stack-trace'.InnerText); # <failure ...>Stacktrace</failure>
            $XmlWriter.WriteEndElement(); # </failure>
        }
        if ($_.result.Equals('Skipped')) {
            $XmlWriter.WriteStartElement('skipped'); # <skipped ...>
            $XmlWriter.WriteAttributeString('message', $_.reason.message.InnerText); # <... message="Skipped because was flaky" ...>
            $XmlWriter.WriteEndElement(); # <skipped ... />
        }
        if ($_.output) {
            # Output is the non harmful data logged in the console
            $xmlWriter.WriteElementString('system-out', $_.output.InnerText); # <system-out>SOME LOGGER OUTPUT</system-out>
        }
        # JUnit supports a tag for error and error-output, but Unity3D does not provide any difference between this and Failure
        $xmlWriter.WriteEndElement(); # </testcase>
    }
    $XmlWriter.WriteEndElement(); # </testsuite>
}

$XmlWriter.WriteEndElement();  # </testsuites>
$xmlWriter.WriteEndDocument();

# Close XmlWriter
$XmlWriter.Flush();
$XmlWriter.Close();
