// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//= require_tree .

$(document).ready(function() {
  // dynamically set values for delete synchronization fields from checked boxes
  $('.checkbox_form').each(function(){
    var form = this;
    aggregateValues(form);
  });

  $('.checkbox_form').on('change', 'input.check_boxes', function(){
    var form = $(this).closest('.checkbox_form');
    aggregateValues(form);
  });

  function aggregateValues(form) {
    var inputValues = [];
    $(form).find('input:checked').each(function(){
      inputValues.push($(this).val());
    });
    $(form).next().find('input[name="notebook_board[notebook]"]').val(inputValues);
  }

  // filter already-selected boards from map dropdowns
  $('select').on('change', function(){
    var $changed  = $(this);
    var selects   = $('.edit_notebook_board').find('select');
    var selected  = selects.find(':selected').text();

    selects.each(function(){
      if (this.name != $changed.attr('name')) {
        var options = $(this).find("option");
        options.each(function(){
          var option = $(this);
          if (!option.is(':selected') && option.text() !== "---Create New---") {
            if (selected.indexOf(option.text()) != -1) {
              option.prop('disabled', true);
            } else {
              option.prop('disabled', false);
            }
          }
        });
      }
    });
  });

});