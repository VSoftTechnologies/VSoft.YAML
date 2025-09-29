// reference https://docwiki.embarcadero.com/RADStudio/Athens/en/Compiler_Versions

 //Basic Version of Compiler Supported
{$IFDEF CONDITIONALEXPRESSIONS}  //Started being defined with D2009
   {$IF CompilerVersion < 23.0} // Before RAD Studio XE2
      {$DEFINE UNSUPPORTED_COMPILER_VERSION}
   {$IFEND}
  {$IF CompilerVersion > 23.0 } //XE3 or later
    {$LEGACYIFEND ON}
  {$IFEND}
{$ELSE}
  {$DEFINE UNSUPPORTED_COMPILER_VERSION}
{$ENDIF}

{$IF CompilerVersion > 23.0 } //XE3 or later
    {$DEFINE XE3PLUS}
{$IFEND}

{$IF CompilerVersion < 27.0 } //XE5 or earlier
  //No TryStrToUInt64
    {$DEFINE XE5SDOWN}
{$IFEND}

{$IF CompilerVersion > 30.0 }
  {$DEFINE HASBUFFEREDFILESTREAM}
{$IFEND}


{$IF CompilerVersion > 32.0 }
    {$DEFINE D10_3PLUS}
{$IFEND}

{$IF CompilerVersion > 35.0 } //12.0 or later
  {$DEFINE D12PLUS}
{$IFEND}

{$IF CompilerVersion > 36.0 } //13.0 or later
  {$DEFINE NORETURN}
  {$DEFINE D13PLUS}
{$IFEND}

{$SCOPEDENUMS ON}

