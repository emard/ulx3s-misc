<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml" version="1.0" indent="yes" omit-xml-declaration="no"/>
<xsl:strip-space elements="*"/>
<xsl:param name="FPGA_DEVICE"/>
<xsl:param name="CONSTRAINTS_FILES"/>
<xsl:param name="STRATEGY_FILE"/>
<xsl:param name="XCF_FILE"/>
<xsl:param name="TOP_MODULE"/>
<xsl:param name="TOP_MODULE_FILE"/>
<xsl:param name="VERILOG_FILES"/>
<xsl:param name="VHDL_FILES"/>
<xsl:param name="XCI_FILES"/>
<xsl:template match="node()|@*">
  <xsl:copy>
    <xsl:apply-templates select="node()|@*"/>
  </xsl:copy>
</xsl:template>
<xsl:template match="Project/Configuration/Option[@Name='Part']/@Val">
  <xsl:attribute name="Val">
    <xsl:value-of select="$FPGA_DEVICE"/>
  </xsl:attribute>
</xsl:template>
<xsl:template match="BaliProject/Implementation/Options/@top">
  <xsl:attribute name="top">
    <xsl:value-of select="$TOP_MODULE"/>
  </xsl:attribute>
</xsl:template>
<xsl:template match="BaliProject/Implementation/Options/@def_top">
  <xsl:attribute name="def_top">
    <xsl:value-of select="$TOP_MODULE"/>
  </xsl:attribute>
</xsl:template>

<xsl:template match="BaliProject/Implementation/Source[@type_short='Programming']/@name">
  <xsl:attribute name="name">
    <xsl:value-of select="$XCF_FILE"/>
  </xsl:attribute>
</xsl:template>
<xsl:template match="BaliProject/Strategy/@file">
  <xsl:attribute name="file">
    <xsl:value-of select="$STRATEGY_FILE"/>
  </xsl:attribute>
</xsl:template>

<xsl:template match="Project/FileSets/FileSet[@Name='sources_1']">
  <xsl:element name="FileSet">
    <xsl:attribute name="Name">
      <xsl:value-of select="'sources_1'"/>
    </xsl:attribute>
    <xsl:attribute name="Type">
      <xsl:value-of select="'DesignSrcs'"/>
    </xsl:attribute>
    <xsl:attribute name="RelSrcDir">
      <xsl:value-of select="'$PSRCDIR/sources_1'"/>
    </xsl:attribute>
    <xsl:element name="Filter">
      <xsl:attribute name="Type">
        <xsl:value-of select="'Srcs'"/>
      </xsl:attribute>
    </xsl:element>
    <xsl:call-template name="tokenize">
      <xsl:with-param name="prefix" select="'$PPRDIR/'"/>
      <xsl:with-param name="string" select="normalize-space($VHDL_FILES)"/>
    </xsl:call-template>
    <xsl:call-template name="tokenize">
      <xsl:with-param name="prefix" select="'$PPRDIR/'"/>
      <xsl:with-param name="string" select="normalize-space($VERILOG_FILES)"/>
    </xsl:call-template>
    <xsl:element name="Config">
      <xsl:element name="Option">
        <xsl:attribute name="Name">
          <xsl:value-of select="'DesignMode'"/>
        </xsl:attribute>
        <xsl:attribute name="Val">
          <xsl:value-of select="'RTL'"/>
        </xsl:attribute>
      </xsl:element>
      <xsl:element name="Option">
        <xsl:attribute name="Name">
          <xsl:value-of select="'TopModule'"/>
        </xsl:attribute>
        <xsl:attribute name="Val">
          <xsl:value-of select="$TOP_MODULE"/>
        </xsl:attribute>
      </xsl:element>
      <xsl:element name="Option">
        <xsl:attribute name="Name">
          <xsl:value-of select="'TopAutoSet'"/>
        </xsl:attribute>
        <xsl:attribute name="Val">
          <xsl:value-of select="'TRUE'"/>
        </xsl:attribute>
      </xsl:element>
    </xsl:element>
  </xsl:element>
</xsl:template>

<xsl:template match="Project/FileSets/FileSet[@Name='constrs_1']">
  <xsl:element name="FileSet">
    <xsl:attribute name="Name">
      <xsl:value-of select="'constrs_1'"/>
    </xsl:attribute>
    <xsl:attribute name="Type">
      <xsl:value-of select="'Constrs'"/>
    </xsl:attribute>
    <xsl:attribute name="RelSrcDir">
      <xsl:value-of select="'$PSRCDIR/constrs_1'"/>
    </xsl:attribute>
    <xsl:element name="Filter">
      <xsl:attribute name="Type">
        <xsl:value-of select="'Constrs'"/>
      </xsl:attribute>
    </xsl:element>
    <xsl:call-template name="tokenize">
      <xsl:with-param name="prefix" select="'$PPRDIR/'"/>
      <xsl:with-param name="string" select="normalize-space($CONSTRAINTS_FILES)"/>
    </xsl:call-template>
    <xsl:element name="Config">
      <xsl:element name="Option">
        <xsl:attribute name="Name">
          <xsl:value-of select="'ConstrsType'"/>
        </xsl:attribute>
        <xsl:attribute name="Val">
          <xsl:value-of select="'XDC'"/>
        </xsl:attribute>
      </xsl:element>
    </xsl:element>
  </xsl:element>
</xsl:template>

<xsl:template match="Project/FileSets/FileSet[@Name='sim_1']">
    <xsl:call-template name="tokenize_xci">
      <xsl:with-param name="prefix" select="'$PSRCDIR/sources_1/ip/'"/>
      <xsl:with-param name="string" select="normalize-space($XCI_FILES)"/>
    </xsl:call-template>
</xsl:template>

<xsl:template name="tokenize_xci">
  <xsl:param name="string"/>
  <xsl:param name="prefix"/>
  <xsl:choose>
    <xsl:when test="contains($string,' ')">

  <xsl:element name="FileSet">
    <xsl:attribute name="Name">
      <xsl:value-of select="substring-before($string,' ')"/>
    </xsl:attribute>
    <xsl:attribute name="Type">
      <xsl:value-of select="'BlockSrcs'"/>
    </xsl:attribute>
    <xsl:attribute name="RelSrcDir">
      <xsl:value-of select="concat('$PSRCDIR/',substring-before($string,' '))"/>
    </xsl:attribute>

      <xsl:element name="File">
        <xsl:attribute name="Path">
          <xsl:value-of select="concat($prefix,substring-before($string,' '),'/',substring-before($string,' '),'.xci')"/>
        </xsl:attribute>
        <xsl:element name="FileInfo">
          <xsl:element name="Attr">
            <xsl:attribute name="Name">
              <xsl:value-of select="'UsedIn'"/>
            </xsl:attribute>
            <xsl:attribute name="Val">
              <xsl:value-of select="'synthesis'"/>
            </xsl:attribute>
          </xsl:element>
        </xsl:element>
      </xsl:element>

  </xsl:element>

      <xsl:call-template name="tokenize_xci">
        <xsl:with-param name="string" select="substring-after($string,' ')"/>
        <xsl:with-param name="prefix" select="$prefix"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$string != ''">
      <xsl:element name="File">
        <xsl:attribute name="Path">
          <xsl:value-of select="concat($prefix,$string,'/',$string,'.xci')"/>
        </xsl:attribute>
        <xsl:element name="FileInfo">
          <xsl:element name="Attr">
            <xsl:attribute name="Name">
              <xsl:value-of select="'UsedIn'"/>
            </xsl:attribute>
            <xsl:attribute name="Val">
              <xsl:value-of select="'synthesis'"/>
            </xsl:attribute>
          </xsl:element>
        </xsl:element>
      </xsl:element>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="tokenize">
  <xsl:param name="string"/>
  <xsl:param name="prefix"/>
  <xsl:choose>
    <xsl:when test="contains($string,' ')">
      <xsl:element name="File">
        <xsl:attribute name="Path">
          <xsl:value-of select="concat($prefix,substring-before($string,' '))"/>
        </xsl:attribute>
        <xsl:element name="FileInfo">
          <xsl:element name="Attr">
            <xsl:attribute name="Name">
              <xsl:value-of select="'UsedIn'"/>
            </xsl:attribute>
            <xsl:attribute name="Val">
              <xsl:value-of select="'synthesis'"/>
            </xsl:attribute>
          </xsl:element>
        </xsl:element>
      </xsl:element>
      <xsl:call-template name="tokenize">
        <xsl:with-param name="string" select="substring-after($string,' ')"/>
        <xsl:with-param name="prefix" select="$prefix"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="$string != ''">
      <xsl:element name="File">
        <xsl:attribute name="Path">
          <xsl:value-of select="concat($prefix,$string)"/>
        </xsl:attribute>
        <xsl:element name="FileInfo">
          <xsl:element name="Attr">
            <xsl:attribute name="Name">
              <xsl:value-of select="'UsedIn'"/>
            </xsl:attribute>
            <xsl:attribute name="Val">
              <xsl:value-of select="'synthesis'"/>
            </xsl:attribute>
          </xsl:element>
        </xsl:element>
      </xsl:element>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>


</xsl:stylesheet>
