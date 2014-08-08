var
	gulp		= require('gulp'),
	browserify	= require('browserify'),
	coffeeify	= require('coffeeify'),
	source		= require('vinyl-source-stream'),
	filesize	= require('gulp-filesize'),
	rename		= require('gulp-rename'),
	streamify	= require('gulp-streamify'),
	uglify		= require('gulp-uglify');

var pkg = require('./package.json');

gulp.task('default', function(){
	bundle = browserify('./src/index.coffee')
	bundle
		.transform(coffeeify)
		.bundle({
			standalone: 'linkup'
		})
		.pipe( source(pkg.name + '.js') )
		.pipe( gulp.dest('dist') )
		.pipe( rename(pkg.name + '.min.js') )
		.pipe( streamify(uglify()) )
		.pipe( gulp.dest('dist') );
	// todo: filesize
});