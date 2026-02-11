function childIssueShowOrHide(parentTR) {
  var children = slaTRs.filter(function (index) {
    return index >= parentTR.attr("cs") - 0 && index <= parentTR.attr("ce") - 0;
  });

  if (children.is(":visible")) {
    parentTR.removeClass("expand").addClass("collapse");
    children
      .hide("fast")
      .filter(".haschild")
      .removeClass("expand")
      .addClass("collapse");
  } else {
    parentTR.removeClass("collapse").addClass("expand");
    children.filter(".idnt-" + (parentTR.attr("rank") - 0 + 1)).show("fast");
  }
}

function selectedTreeOpen() {
  var targetParents = slaTRs.filter("tr:has(td.checkbox > input:checked)");
  for (var i = 0; i < targetParents.length; i++) {
    var parentTR = targetParents.eq(i);
    if (!parentTR.hasClass("haschild")) {
      continue;
    }

    //show
    var children = slaTRs.filter(function (index) {
      return (
        index >= parentTR.attr("cs") - 0 && index <= parentTR.attr("ce") - 0
      );
    });
    children
      .show()
      .filter(".haschild")
      .removeClass("collapse")
      .addClass("expand");
    parentTR.removeClass("collapse").addClass("expand");
  }
}

function selectedTreeClose() {
  var targetParents = slaTRs.filter("tr:has(td.checkbox > input:checked)");
  for (var i = 0; i < targetParents.length; i++) {
    var parentTR = targetParents.eq(i);
    if (!parentTR.hasClass("haschild")) {
      continue;
    }

    //hide
    var children = slaTRs.filter(function (index) {
      return (
        index >= parentTR.attr("cs") - 0 && index <= parentTR.attr("ce") - 0
      );
    });
    children
      .hide()
      .filter(".haschild")
      .removeClass("expand")
      .addClass("collapse");
    parentTR.removeClass("expand").addClass("collapse");
  }
}

function allExpandNext() {
  var parentTR = slaTRs.filter("tr:has(td.checkbox > input:checked)");
  if (parentTR.length != 1) {
    return;
  }
  if (!parentTR.hasClass("haschild")) {
    return;
  }

  for (var rank = 0; rank <= parentTR.attr("rank") - 0; rank++) {
    //show
    slaTRs
      .filter("tr[rank='" + rank + "'].haschild.collapse")
      .each(function () {
        childIssueShowOrHide($(this));
      });
  }
}

$(document).ready(function () {
  function setupAccordion() {
    // Note: slaTRs is defined in the global scope for access by other functions
    slaTRs = $("table.list > tbody > tr");

    if (slaTRs.closest("table.list").data("subtaskListAccordionSetupDone")) {
      return; // Already set up
    }

    //set toggle event
    slaTRs.find("td.subject > span.treearrow").click(function () {
      childIssueShowOrHide($(this).parent().parent());
      return false;
    });

    //all expand
    $("a.subtask_all_expand").click(function () {
      slaTRs
        .show()
        .filter(".haschild")
        .removeClass("collapse")
        .addClass("expand");

      return false;
    });

    //all collapse
    $("a.subtask_all_collapse").click(function () {
      slaTRs.filter(".idnt").hide();
      slaTRs.filter(".haschild").removeClass("expand").addClass("collapse");
      return false;
    });

    //link move
    $("div.accordion_control").insertAfter("#issue_tree > p");

    // Add marker to indicate setup is done
    slaTRs.closest("table.list").data("subtaskListAccordionSetupDone", true);
  }

  /**
   * Set up form change detection.
   * This method's purpose is to detect when the issue view is replaced by
   * other plugins like Redmine RT.
   */
  function setupFormChangeDetection() {
    const targetNode = $("div.issue.details").parent()[0];

    if (targetNode) {
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          if (mutation.type === "childList") {
            mutation.addedNodes.forEach((node) => {
              if (
                node.nodeType === Node.ELEMENT_NODE &&
                ($(node).is("div.issue.details") ||
                  $(node).is($("#issue_tree table.list.issues").parent("form")))
              ) {
                setupAccordion();
              }
            });
          }
        });
      });

      observer.observe(targetNode, {
        childList: true,
        subtree: true,
        attributes: false,
      });
    }
  }

  function initialize() {
    setupAccordion();
    setupFormChangeDetection();
  }

  initialize();
});
