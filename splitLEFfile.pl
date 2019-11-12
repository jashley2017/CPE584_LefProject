#! /usr/local/bin/perl
# 
# splitLEF_file.pl
# 
# Copyright (c) 2017 by Cypress Semiconductor
# Kentucky CAD Center (KYCC)
# 
# Date  : Apr 18, 2017
# Author: Joseph Elias (jfe) @ KYCC
# 
# Description:
#  Input is a LEF file which contains module
#  definitions for many cells, and the output is
#  individual .lef files
# 
# Revision History:
#   jfe  04/17/17  initial from splitVerilogFile
#   jfe  04/18/17  update for f45, caps, MACRO phrase
#   jfe  03/29/19  add subdir for each cell, for AIP
#   jfe  04/02/19  comprehend splitting atpg files as well
#   jfe  10/15/19  look for lcName
#

main(@ARGV);

sub main
{
  ($fn,$aip)=@_;
  if ($fn eq "") {&syntax;}
  open(in,"$fn") or die "Could not open $fn\n";
  @lefLines=<in>;
  close(in);

  if ($aip eq "AIP")
  {
    print "Files will be in the <cellName>/<cellName>.lef location\n";
    $aip=1;
  }
  elsif ($aip ne "")
  {
    print "Incorrect option\n";
    &syntax;
  }
  else
  {
    print "Files will be in the splitLEFfolder\n";
    $aip=0;
  }

  if ($aip==0)
  {
    if (!(-e "splitLEF"))
    {
      `mkdir splitLEF`;
    }
  }

  $foundModule=0;
  $functLine="";
  open(funct,">functions.txt") or die "Could not open functions.txt";
  foreach $line (@lefLines)
  {
    chomp($line);
    #print "$line\n";

    # do this first as the module/model needs to exist
    $lcName=lc($name);
    if (($foundModule==1) && (lc($line)=~/^endmodule|^end model|^end $lcName/) )
    {
      #print "end line: $line\n";
      print out "$line\n";
      print funct "$functLine\n";
      close(out); #last line, close out file
      $foundModule=0;
    }
    # 
    # for atpg, there is no end statement, so print out if there is
    # another module line found
    #
    if (($foundModule==1) && (lc($line)=~/^model/) )
    {
      #print "$name end line: $line\n";
      print out "$line\n";
      print funct "$functLine\n";
      close(out); #last line, close out file
      $foundModule=0;
    }
    
    # avoid using end model line to grab model name
    # reset function statement
    if (($foundModule==0) && (lc($line)=~/^module|^model|^macro/))
    {
      #print "cell line: $line\n";
      $foundModule=1;
      $functLine="";

      if ($line=~/^module|^model|^macro/)
      {
        ($txt,$name,$pins)=split(/model |module |macro | +\(|\)/,$line);
        print "$name\n";
      }
      else
      {
        ($txt,$name,$pins)=split(/MODEL |MODULE |MACRO | +\(|\)/,$line);
        print "$name\n";
      }

      # put in a cell name subdirectory for AIP checks
      if ($aip==1)
      {
        if (!(-e "$name"))
        {
          `mkdir $name`;
        }
        $outfn="$name/$name.lef";
      }
      else
      {
        $outfn="splitLEF/$name.lef";
      }

      open(out,">$outfn") or die "Could not open $outfn\n$line\n";
      print funct "$name";

    }

    if ($foundModule==1)
    {
      #print "line:$line\n";
      
      #
      # for vlog syntax
      #
      if ($line=~/ U/)
      {
        $funct=$line;
        $funct=~s/\=|\;//g;
        #foreach $field (@fields) { print "|$field|\n"; }
        $functLine=$functLine."|".$funct;
      }
      
      #
      # for atpg syntax
      #
      if (lc($line)=~/primitive|instance/)
      {
        if ($line=~/primitive|instance/)
        {
          @fields=split(/primitive|instance/,$line);
        }
        else
        {
          @fields=split(/PRIMITIVE|INSTANCE/,$line);
        }
        $funct=$fields[1];
        $funct=~s/\s+|\=|\;//g;
        #foreach $field (@fields) { print "|$field|\n"; }
        $functLine=$functLine."|".$funct;
      }
      print out "$line\n";
    }
  }
  print "Done with file $fn\n";
  close(funct);
}

sub syntax
{
  print "splitLEF_file.pl <fn> [AIP]\n";
  print " where fn is a LEF file with many macro statements\n";
  print " the output is many files in splitLEF folder\n";
  print " and a functions.txt file that has each macro and function\n";
  print " statement in a file delimited by |\n";
  print "If the AIP option is added, each cell will be put in \n";
  print " individual subdirs with one cell LEF file in each, for AIP\n";
  die "\n";
}

1;
