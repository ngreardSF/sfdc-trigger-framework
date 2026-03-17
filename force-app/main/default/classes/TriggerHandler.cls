/**
 * @description Trigger handler framework imported from https://github.com/kevinohara80/sfdc-trigger-framework
 */
public virtual class TriggerHandler {

  // static map of handlername, times run() was invoked
  private static Map<String, LoopCount> loopCountMap;
  private static Set<String> bypassedHandlers;

  @TestVisible
  private List<SObject> triggerNew;
  @TestVisible
  private Map<Id, SObject> triggerNewMap;
  @TestVisible
  private List<SObject> triggerOld;
  @TestVisible
  private Map<Id, SObject> triggerOldMap;

  // the current context of the trigger, overridable in tests
  @TestVisible
  private TriggerContext context;

  // the current context of the trigger, overridable in tests
  @TestVisible
  private Boolean isTriggerExecuting;

  // static initialization
  static {
    loopCountMap = new Map<String, LoopCount>();
    bypassedHandlers = new Set<String>();
  }
  
  /**
   * @description Default constructor
   */
  public TriggerHandler() {
    this.setTriggerContext();
  }

  /**
   * @description Constructor with handler name
   * @param handlerName Name of the handler
   */
  public TriggerHandler(String handlerName) {
    this.handlerName = handlerName;
    this.setTriggerContext();
  }

  /***************************************
   * public instance methods
   ***************************************/

  /** @description Main method that will be called during execution */
  public void run() {

    if(!validateRun()) {
      return;
    }

    addToLoopCount();

    // dispatch to the correct handler method
    // only one method should be implemented in the trigger handler (with parameters prefered for mocking capabilities)
    if(this.context == TriggerContext.BEFORE_INSERT) {
      this.beforeInsert();
      this.beforeInsert(this.triggerNew);
    } else if(this.context == TriggerContext.BEFORE_UPDATE) {
      this.beforeUpdate();
      this.beforeUpdate(this.triggerNewMap, this.triggerOldMap);
    } else if(this.context == TriggerContext.BEFORE_DELETE) {
      this.beforeDelete();
      this.beforeDelete(this.triggerOldMap);
    } else if(this.context == TriggerContext.AFTER_INSERT) {
      this.afterInsert();
      this.afterInsert(this.triggerNew);
      this.afterInsert(this.triggerNewMap);
    } else if(this.context == TriggerContext.AFTER_UPDATE) {
      this.afterUpdate();
      this.afterUpdate(this.triggerNewMap, this.triggerOldMap);
    } else if(this.context == TriggerContext.AFTER_DELETE) {
      this.afterDelete();
      this.afterDelete(this.triggerOldMap);
    } else if(this.context == TriggerContext.AFTER_UNDELETE) {
      this.afterUndelete();
      this.afterUndelete(this.triggerNewMap);
    }
  }

  /** @description Sets the maximum loop count for the handler
   * @param max Maximum number of times run() can be invoked
   */
  public void setMaxLoopCount(Integer max) {
    String handlerName = getHandlerName();
    LoopCount loopCount = TriggerHandler.loopCountMap.get(handlerName);
    if(loopCount == null){
      TriggerHandler.loopCountMap.put(handlerName, new LoopCount(max));
    }
    else{
      loopCount.setMax(max);
    }
  }

  /** @description Clears the maximum loop count for the handler
   */
  public void clearMaxLoopCount() {
    this.setMaxLoopCount(-1);
  }

  /***************************************
   * public static methods
   ***************************************/

  /** @description Bypasses the specified handler
   * @param handlerName Name of the handler to bypass
   */
  public static void bypass(String handlerName) {
    TriggerHandler.bypassedHandlers.add(handlerName);
  }

  /** @description Clears the bypass for the specified handler
   * @param handlerName Name of the handler to clear bypass for
   */
  public static void clearBypass(String handlerName) {
    TriggerHandler.bypassedHandlers.remove(handlerName);
  }

  /** @description Returns whether the specified handler is bypassed
   * @param handlerName Name of the handler to check
   * @return True if the handler is bypassed, false otherwise
   */
  public static Boolean isBypassed(String handlerName) {
    return TriggerHandler.bypassedHandlers.contains(handlerName);
  }

  /** @description Clears all handler bypasses */
  public static void clearAllBypasses() {
    TriggerHandler.bypassedHandlers.clear();
  }

  /***************************************
   * private instancemethods
   ***************************************/

  /** @description Sets the trigger context from the current Trigger state */
  @TestVisible
  private void setTriggerContext() {
    this.setTriggerContext(null, false);
  }

  /** @description Sets the trigger context, optionally for test mode
   * @param ctx Trigger context string (e.g. 'before insert')
   * @param testMode When true, allows execution outside of a running trigger
   */
  @TestVisible
  private void setTriggerContext(String ctx, Boolean testMode) {
    if(!Trigger.isExecuting && !testMode) {
      this.isTriggerExecuting = false;
      return;
    } else {
      this.isTriggerExecuting = true;
    }
    
    if((Trigger.isExecuting && Trigger.isBefore && Trigger.isInsert) ||
        (ctx != null && ctx == 'before insert')) {
      this.context = TriggerContext.BEFORE_INSERT;
    } else if((Trigger.isExecuting && Trigger.isBefore && Trigger.isUpdate) ||
        (ctx != null && ctx == 'before update')){
      this.context = TriggerContext.BEFORE_UPDATE;
    } else if((Trigger.isExecuting && Trigger.isBefore && Trigger.isDelete) ||
        (ctx != null && ctx == 'before delete')) {
      this.context = TriggerContext.BEFORE_DELETE;
    } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isInsert) ||
        (ctx != null && ctx == 'after insert')) {
      this.context = TriggerContext.AFTER_INSERT;
    } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isUpdate) ||
        (ctx != null && ctx == 'after update')) {
      this.context = TriggerContext.AFTER_UPDATE;
    } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isDelete) ||
        (ctx != null && ctx == 'after delete')) {
      this.context = TriggerContext.AFTER_DELETE;
    } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isUndelete) ||
        (ctx != null && ctx == 'after undelete')) {
      this.context = TriggerContext.AFTER_UNDELETE;
    }

    //store value in a local variables, then we will be able to mock triggerhandler
    this.triggerNew = Trigger.new;
    this.triggerNewMap = Trigger.newMap;
    this.triggerOld = Trigger.old;
    this.triggerOldMap = Trigger.oldMap;
  }

  // increment the loop count
  @TestVisible
  private void addToLoopCount() {
    String handlerName = getHandlerName();

    LoopCount loopCount = TriggerHandler.loopCountMap.get(handlerName);
    if(loopCount != null) {
      Boolean exceeded = loopCount.increment();
      if(exceeded) {
        Integer max = loopCount.max;
        throw new TriggerHandlerException('Maximum loop count of ' + String.valueOf(max) + ' reached in ' + handlerName);
      }
    }
  }

  // make sure this trigger should continue to run
  @TestVisible
  private Boolean validateRun() {
    if(!this.isTriggerExecuting || this.context == null) {
      throw new TriggerHandlerException('Trigger handler called outside of Trigger execution');
    }

    return !TriggerHandler.bypassedHandlers.contains(getHandlerName());
  }

  @TestVisible
  private String getHandlerName() {
    if(String.isBlank(this.handlerName)) {
      this.handlerName = this.toString().substringBefore(':');
    }
    return handlerName;
  }
  private String handlerName {get; set;}

  /***************************************
   * context methods
   ***************************************/

  /** @description Context-specific methods for override. Use only one implementation in the trigger (parameterized versions preferred for mocking). */
  @TestVisible
  protected virtual void beforeInsert(){}
  @TestVisible
  protected virtual void beforeUpdate(){}
  @TestVisible
  protected virtual void beforeDelete(){}
  @TestVisible
  protected virtual void afterInsert(){}
  @TestVisible
  protected virtual void afterUpdate(){}
  @TestVisible
  protected virtual void afterDelete(){}
  @TestVisible
  protected virtual void afterUndelete(){}

  /** @description Before insert handler with new records
   * @param triggerNew List of new SObject records
   */
  @TestVisible
  protected virtual void beforeInsert(List<SObject> triggerNew){}
  /** @description Before update handler with new and old record maps
   * @param triggerNewMap Map of new SObject records by Id
   * @param triggerOldMap Map of old SObject records by Id
   */
  @TestVisible
  protected virtual void beforeUpdate(Map<Id,SObject> triggerNewMap, Map<Id,SObject> triggerOldMap){}
  /** @description Before delete handler with records to be deleted
   * @param triggerNewMap Map of SObject records by Id (Trigger.oldMap in delete context)
   */
  @TestVisible
  protected virtual void beforeDelete(Map<Id,SObject> triggerNewMap){}
  /** @description After insert handler with new records
   * @param triggerNew List of new SObject records
   */
  @TestVisible
  protected virtual void afterInsert(List<SObject> triggerNew){}
  /** @description After insert handler with new record map
   * @param triggerNewMap Map of new SObject records by Id
   */
  @TestVisible
  protected virtual void afterInsert(Map<Id,SObject> triggerNewMap){}
  /** @description After update handler with new and old record maps
   * @param triggerNewMap Map of new SObject records by Id
   * @param triggerOldMap Map of old SObject records by Id
   */
  @TestVisible
  protected virtual void afterUpdate(Map<Id,SObject> triggerNewMap, Map<Id,SObject> triggerOldMap){}
  /** @description After delete handler with deleted records
   * @param triggerOldMap Map of deleted SObject records by Id
   */
  @TestVisible
  protected virtual void afterDelete(Map<Id,SObject> triggerOldMap){}
  /** @description After undelete handler with recovered records
   * @param triggerNewMap Map of recovered SObject records by Id
   */
  @TestVisible
  protected virtual void afterUndelete(Map<Id,SObject> triggerNewMap){}

  /***************************************
   * inner classes
   ***************************************/

  /** @description Inner class for managing the loop count per handler */
  @TestVisible
  private class LoopCount {
    private Integer max;
    private Integer count;

    /** @description Default constructor */
    public LoopCount() {
      this.max = 5;
      this.count = 0;
    }

    /** @description Constructor with maximum loop count
     * @param max Maximum number of loop iterations allowed
     */
    public LoopCount(Integer max) {
      this.max = max;
      this.count = 0;
    }

    /** @description Increments the loop count
     * @return True if the maximum count was exceeded
     */
    public Boolean increment() {
      this.count++;
      return this.exceeded();
    }

    /** @description Returns whether the maximum loop count has been exceeded
     * @return True if the count exceeds the maximum
     */
    public Boolean exceeded() {
      return this.max >= 0 && this.count > this.max;
    }

    /** @description Returns the maximum loop count
     * @return The maximum allowed loop count
     */
    public Integer getMax() {
      return this.max;
    }

    /** @description Returns the current loop count
     * @return The current number of iterations
     */
    public Integer getCount() {
      return this.count;
    }

    /** @description Sets the maximum loop count
     * @param max Maximum number of loop iterations allowed
     */
    public void setMax(Integer max) {
      this.max = max;
    }
  }

  /** @description Possible trigger contexts */
  @TestVisible
  private enum TriggerContext {
    BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE,
    AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE,
    AFTER_UNDELETE
  }

  /** @description Exception thrown by the trigger handler framework */
  public class TriggerHandlerException extends Exception {}
}