const fs = require( "fs" );
const pathlib = require( "path" );
const gaze = require( "gaze" );
const packageJson = require( "./package.json" );

// == build script =================================================================================
function build( path, debugmode ) {
  const dir = pathlib.dirname( path );

  let data = fs.readFileSync( path, { encoding: "utf8" } );

  // -- @include -----------------------------------------------------------------------------------
  {
    const re = /@include{(.+?)}/;
    while ( true ) {
      const result = re.exec( data );
      if ( !result ) { break; }

      const ifile = build( pathlib.join( dir, result[ 1 ] ), debugmode );
      data = data.replace( result[ 0 ], ifile );
    }
  }

  // -- @version -----------------------------------------------------------------------------------
  {
    const re = /@version/;
    while ( true ) {
      const result = re.exec( data );
      if ( !result ) { break; }

      data = data.replace( result[ 0 ], packageJson.version );
    }
  }

  return data;
};

// == watch ========================================================================================
console.log( "Watching..." );
gaze( "src/**", ( error, watcher ) => {
  watcher.on( "all", ( event, path ) => {
    let bgData = build( "src/index.lua", false );
    fs.writeFileSync( "dist/automaton.lua", bgData, { encoding: "utf8" } );
    console.log( "Built: " + new Date().toLocaleTimeString() );
  } );
} );
